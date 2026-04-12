package aleem.flutter.defender

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

private const val PREFS_NAME = "flutter_defender_prefs"
private const val KEY_LAST_BACKGROUNDED_AT_MS = "last_backgrounded_at_ms"
private const val KEY_WAS_AUTHENTICATED = "was_authenticated"
private const val KEY_ACTIVE_GUARD_KIND = "active_guard_kind"

private class OverlayAwareWindowCallback(
    val delegateCallback: Window.Callback,
    private val onObscuredTouch: () -> Unit,
    private val isActive: () -> Boolean
) : Window.Callback by delegateCallback {
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (isActive() && event.isObscuredTouch()) {
            onObscuredTouch()
            return true
        }
        return delegateCallback.dispatchTouchEvent(event)
    }
}

private fun MotionEvent.isObscuredTouch(): Boolean {
    val obscured = flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
    val partiallyObscured =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
    return obscured || partiallyObscured
}

class FlutterDefenderPlugin : FlutterPlugin, ActivityAware, DefenderHostApi {
    private var applicationContext: Context? = null
    private var preferences: SharedPreferences? = null
    private var activity: Activity? = null
    private var flutterApi: DefenderFlutterApi? = null
    private var screenCaptureCallbackHandle: Any? = null
    private var windowFocusListener: ViewTreeObserver.OnWindowFocusChangeListener? = null
    private var windowCallbackWrapper: OverlayAwareWindowCallback? = null
    private var secureActive = false
    private var overlayHardeningActive = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        preferences =
            binding.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        flutterApi = DefenderFlutterApi(binding.binaryMessenger)
        DefenderHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DefenderHostApi.setUp(binding.binaryMessenger, null)
        unregisterScreenCaptureCallback()
        removeWindowFocusListener()
        restoreWindowCallback()
        flutterApi = null
        preferences = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerScreenCaptureCallback()
        installWindowFocusListener()
        applyProtectionState()
        emitForegroundState(currentForegroundState())
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterScreenCaptureCallback()
        removeWindowFocusListener()
        restoreWindowCallback()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerScreenCaptureCallback()
        installWindowFocusListener()
        applyProtectionState()
        emitForegroundState(currentForegroundState())
    }

    override fun onDetachedFromActivity() {
        unregisterScreenCaptureCallback()
        removeWindowFocusListener()
        restoreWindowCallback()
        activity = null
    }

    override fun setProtectionState(secureActive: Boolean, overlayHardeningActive: Boolean) {
        this.secureActive = secureActive
        this.overlayHardeningActive = overlayHardeningActive
        applyProtectionState()
    }

    override fun getRuntimeState(): NativeRuntimeState {
        return NativeRuntimeState(
            isForeground = currentForegroundState(),
            isScreenCaptured = false,
            isEmulator = isEmulator(),
            supportsOverlayHardening = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        )
    }

    override fun saveLifecycleSnapshot(snapshot: LifecycleSnapshot) {
        preferences?.edit()?.apply {
            if (snapshot.lastBackgroundedAtMs != null) {
                putLong(KEY_LAST_BACKGROUNDED_AT_MS, snapshot.lastBackgroundedAtMs)
            } else {
                remove(KEY_LAST_BACKGROUNDED_AT_MS)
            }
            putBoolean(KEY_WAS_AUTHENTICATED, snapshot.wasAuthenticated == true)
            putInt(KEY_ACTIVE_GUARD_KIND, snapshot.activeGuardKind?.raw ?: DefenderGuardKind.NONE.raw)
        }?.apply()
    }

    override fun loadLifecycleSnapshot(): LifecycleSnapshot {
        val prefs = preferences
        if (prefs == null) {
            return LifecycleSnapshot()
        }

        val hasTimestamp = prefs.contains(KEY_LAST_BACKGROUNDED_AT_MS)
        val storedKind = prefs.getInt(KEY_ACTIVE_GUARD_KIND, DefenderGuardKind.NONE.raw)

        return LifecycleSnapshot(
            lastBackgroundedAtMs =
                if (hasTimestamp) prefs.getLong(KEY_LAST_BACKGROUNDED_AT_MS, 0L) else null,
            wasAuthenticated = prefs.getBoolean(KEY_WAS_AUTHENTICATED, false),
            activeGuardKind = DefenderGuardKind.ofRaw(storedKind) ?: DefenderGuardKind.NONE
        )
    }

    override fun clearLifecycleSnapshot() {
        preferences?.edit()?.remove(KEY_LAST_BACKGROUNDED_AT_MS)?.remove(KEY_WAS_AUTHENTICATED)
            ?.remove(KEY_ACTIVE_GUARD_KIND)?.apply()
    }

    private fun applyProtectionState() {
        val activeActivity = activity ?: return
        activeActivity.runOnUiThread {
            if (secureActive) {
                activeActivity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activeActivity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                activeActivity.window.setHideOverlayWindows(overlayHardeningActive)
            }

            setFilterTouchesWhenObscured(
                activeActivity.window.decorView,
                overlayHardeningActive
            )
            updateWindowCallback(activeActivity.window)
        }
    }

    private fun setFilterTouchesWhenObscured(view: View, enabled: Boolean) {
        view.filterTouchesWhenObscured = enabled
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                setFilterTouchesWhenObscured(view.getChildAt(index), enabled)
            }
        }
    }

    private fun updateWindowCallback(window: Window) {
        val callback = window.callback ?: return
        if (!overlayHardeningActive) {
            restoreWindowCallback()
            return
        }
        if (callback is OverlayAwareWindowCallback) {
            windowCallbackWrapper = callback
            return
        }
        val wrapper = OverlayAwareWindowCallback(
            delegateCallback = callback,
            onObscuredTouch = { emitOverlayViolation() },
            isActive = { overlayHardeningActive }
        )
        window.callback = wrapper
        windowCallbackWrapper = wrapper
    }

    private fun restoreWindowCallback() {
        val activeActivity = activity ?: return
        val callback = activeActivity.window.callback
        if (callback is OverlayAwareWindowCallback) {
            activeActivity.window.callback = callback.delegateCallback
        }
        windowCallbackWrapper = null
    }

    private fun registerScreenCaptureCallback() {
        val activeActivity = activity ?: return
        if (screenCaptureCallbackHandle != null || Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        val callback = Activity.ScreenCaptureCallback {
            flutterApi?.onScreenshotDetected {}
        }
        activeActivity.registerScreenCaptureCallback(activeActivity.mainExecutor, callback)
        screenCaptureCallbackHandle = callback
    }

    private fun unregisterScreenCaptureCallback() {
        val activeActivity = activity ?: return
        val callback = screenCaptureCallbackHandle as? Activity.ScreenCaptureCallback ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activeActivity.unregisterScreenCaptureCallback(callback)
        }
        screenCaptureCallbackHandle = null
    }

    private fun installWindowFocusListener() {
        val activeActivity = activity ?: return
        if (windowFocusListener != null) {
            return
        }
        val listener = ViewTreeObserver.OnWindowFocusChangeListener { hasFocus ->
            emitForegroundState(hasFocus)
        }
        activeActivity.window.decorView.viewTreeObserver.addOnWindowFocusChangeListener(listener)
        windowFocusListener = listener
    }

    private fun removeWindowFocusListener() {
        val activeActivity = activity ?: return
        val listener = windowFocusListener ?: return
        val observer = activeActivity.window.decorView.viewTreeObserver
        if (observer.isAlive) {
            observer.removeOnWindowFocusChangeListener(listener)
        }
        windowFocusListener = null
    }

    private fun emitOverlayViolation() {
        flutterApi?.onOverlayViolation {}
    }

    private fun emitForegroundState(active: Boolean) {
        flutterApi?.onForegroundStateChanged(active) {}
    }

    private fun currentForegroundState(): Boolean {
        val activeActivity = activity ?: return true
        return !activeActivity.isFinishing && activeActivity.hasWindowFocus()
    }

    private fun isEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            Build.PRODUCT == "google_sdk" ||
            Build.PRODUCT.contains("sdk") ||
            Build.PRODUCT.contains("emulator") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu")
    }
}
