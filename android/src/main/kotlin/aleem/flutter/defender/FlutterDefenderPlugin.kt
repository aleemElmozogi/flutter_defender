package aleem.flutter.defender

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.ViewTreeObserver
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

class FlutterDefenderPlugin : FlutterPlugin, ActivityAware, DefenderHostApi {
    private companion object {
        const val TAG = "FlutterDefender"
    }

    private var activity: Activity? = null
    private var flutterApi: DefenderFlutterApi? = null
    private var snapshotStore: LifecycleSnapshotStore? = null
    private var advancedSecurityDetector: AdvancedSecurityDetector? = null
    private var secureStorageHelper: SecureStorageHelper? = null
    private var detectorExecutor: ExecutorService? = null
    private var screenCaptureCallbackHandle: Any? = null
    private var windowFocusListener: ViewTreeObserver.OnWindowFocusChangeListener? = null
    private var windowCallbackWrapper: OverlayAwareWindowCallback? = null
    private var secureActive = false
    private var overlayHardeningActive = false
    private var hideOverlayWindowsAvailable = true
    @Volatile
    private var advancedSecuritySignalsCache = AdvancedSecuritySignals(
        rootedOrJailbroken = false,
        proxyEnabled = false,
        vpnEnabled = false,
        debuggerAttached = false,
        tamperingDetected = false,
        tamperingDetails = null
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        snapshotStore = LifecycleSnapshotStore(binding.applicationContext)
        advancedSecurityDetector = AdvancedSecurityDetector(binding.applicationContext)
        secureStorageHelper = SecureStorageHelper(binding.applicationContext)
        detectorExecutor = Executors.newSingleThreadExecutor()
        flutterApi = DefenderFlutterApi(binding.binaryMessenger)
        DefenderHostApi.setUp(binding.binaryMessenger, this)
        scheduleSecurityRefresh()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DefenderHostApi.setUp(binding.binaryMessenger, null)
        unregisterScreenCaptureCallback()
        removeWindowFocusListener()
        restoreWindowCallback()
        flutterApi = null
        snapshotStore = null
        secureStorageHelper = null
        advancedSecurityDetector = null
        detectorExecutor?.shutdownNow()
        detectorExecutor = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        rebindActivityHooks()
    }

    override fun onDetachedFromActivityForConfigChanges() = releaseActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        rebindActivityHooks()
    }

    override fun onDetachedFromActivity() = releaseActivity()

    override fun setProtectionState(secureActive: Boolean, overlayHardeningActive: Boolean) {
        this.secureActive = secureActive
        this.overlayHardeningActive = overlayHardeningActive
        applyProtectionState()
        if (secureActive || overlayHardeningActive) {
            scheduleSecurityRefresh()
        }
    }

    override fun getRuntimeState(): NativeRuntimeState {
        return NativeRuntimeState(
            isForeground = currentForegroundState(),
            isScreenCaptured = false,
            isEmulator = EmulatorDetector.isEmulator(),
            supportsOverlayHardening = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                hideOverlayWindowsAvailable
        )
    }

    override fun getAdvancedSecuritySignals(): AdvancedSecuritySignals {
        return advancedSecuritySignalsCache
    }

    override fun secureWrite(key: String, value: String) {
        val helper = secureStorageHelper
            ?: throw IllegalStateException("Secure storage is unavailable.")
        helper.write(key, value)
    }

    override fun secureRead(key: String): String? {
        val helper = secureStorageHelper
            ?: throw IllegalStateException("Secure storage is unavailable.")
        return helper.read(key)
    }

    override fun secureDelete(key: String) {
        val helper = secureStorageHelper
            ?: throw IllegalStateException("Secure storage is unavailable.")
        helper.delete(key)
    }

    override fun secureClearAll() {
        val helper = secureStorageHelper
            ?: throw IllegalStateException("Secure storage is unavailable.")
        helper.clearAll()
    }

    override fun saveLifecycleSnapshot(snapshot: LifecycleSnapshot) {
        snapshotStore?.save(snapshot)
    }

    override fun loadLifecycleSnapshot(): LifecycleSnapshot {
        return snapshotStore?.load() ?: LifecycleSnapshot()
    }

    override fun clearLifecycleSnapshot() {
        snapshotStore?.clear()
    }

    private fun rebindActivityHooks() {
        registerScreenCaptureCallback()
        installWindowFocusListener()
        applyProtectionState()
        emitForegroundState(currentForegroundState())
        scheduleSecurityRefresh()
    }

    private fun releaseActivity() {
        unregisterScreenCaptureCallback()
        removeWindowFocusListener()
        restoreWindowCallback()
        activity = null
    }

    private fun applyProtectionState() {
        val activeActivity = activity ?: return
        activeActivity.runOnUiThread {
            if (activity !== activeActivity) {
                return@runOnUiThread
            }
            if (secureActive) {
                activeActivity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activeActivity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && hideOverlayWindowsAvailable) {
                try {
                    activeActivity.window.setHideOverlayWindows(overlayHardeningActive)
                } catch (error: SecurityException) {
                    hideOverlayWindowsAvailable = false
                    Log.w(
                        TAG,
                        "System overlay hiding is unavailable; continuing with fallback overlay hardening.",
                        error
                    )
                }
            }
            activeActivity.window.decorView.setFilterTouchesRecursively(overlayHardeningActive)
            updateWindowCallback(activeActivity.window)
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
        val callback = Activity.ScreenCaptureCallback { flutterApi?.onScreenshotDetected {} }
        try {
            activeActivity.registerScreenCaptureCallback(activeActivity.mainExecutor, callback)
            screenCaptureCallbackHandle = callback
        } catch (error: RuntimeException) {
            screenCaptureCallbackHandle = null
            Log.w(TAG, "Screen-capture callback registration failed; continuing without callback.", error)
        }
    }

    private fun unregisterScreenCaptureCallback() {
        val activeActivity = activity ?: return
        val callback = screenCaptureCallbackHandle as? Activity.ScreenCaptureCallback ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                activeActivity.unregisterScreenCaptureCallback(callback)
            } catch (error: RuntimeException) {
                Log.w(TAG, "Screen-capture callback unregistration failed.", error)
            }
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

    private fun emitOverlayViolation() = flutterApi?.onOverlayViolation {}

    private fun emitForegroundState(active: Boolean) {
        flutterApi?.onForegroundStateChanged(active) {}
    }

    private fun currentForegroundState(): Boolean {
        val activeActivity = activity ?: return true
        return !activeActivity.isFinishing && activeActivity.hasWindowFocus()
    }

    private fun scheduleSecurityRefresh() {
        val detector = advancedSecurityDetector ?: return
        val executor = detectorExecutor ?: return
        try {
            executor.execute {
                try {
                    advancedSecuritySignalsCache = detector.collectSignals()
                } catch (error: Throwable) {
                    Log.w(TAG, "Advanced security signal refresh failed.", error)
                }
            }
        } catch (error: RejectedExecutionException) {
            Log.w(TAG, "Advanced security signal refresh was rejected.", error)
        }
    }
}
