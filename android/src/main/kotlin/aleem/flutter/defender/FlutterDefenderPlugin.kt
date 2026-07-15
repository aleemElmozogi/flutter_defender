package aleem.flutter.defender

import android.app.Activity
import android.os.Build
import android.util.Log
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
    private var foregroundLifecycleTracker: ForegroundLifecycleTracker? = null
    private var windowCallbackWrapper: OverlayAwareWindowCallback? = null
    private var secureActive = false
    private var overlayHardeningActive = false
    private var hideOverlayWindowsAvailable = true
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        snapshotStore = LifecycleSnapshotStore(binding.applicationContext)
        advancedSecurityDetector = AdvancedSecurityDetector(binding.applicationContext)
        secureStorageHelper = SecureStorageHelper(binding.applicationContext)
        detectorExecutor = Executors.newSingleThreadExecutor()
        flutterApi = DefenderFlutterApi(binding.binaryMessenger)
        DefenderHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DefenderHostApi.setUp(binding.binaryMessenger, null)
        unregisterScreenCaptureCallback()
        unregisterForegroundLifecycleTracker()
        restoreWindowCallback()
        flutterApi = null
        snapshotStore = null
        secureStorageHelper = null
        advancedSecurityDetector = null
        detectorExecutor?.shutdown()
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

    override fun getAdvancedSecuritySignals(
        callback: (Result<AdvancedSecuritySignals>) -> Unit
    ) {
        val detector = advancedSecurityDetector
            ?: return callback(Result.failure(IllegalStateException("Security detector is unavailable.")))
        runOnWorker(callback) { detector.collectSignals() }
    }

    override fun secureWrite(key: String, value: String, callback: (Result<Unit>) -> Unit) {
        val helper = secureStorageHelper
            ?: return callback(Result.failure(IllegalStateException("Secure storage is unavailable.")))
        runOnWorker(callback) { helper.write(key, value) }
    }

    override fun secureRead(key: String, callback: (Result<String?>) -> Unit) {
        val helper = secureStorageHelper
            ?: return callback(Result.failure(IllegalStateException("Secure storage is unavailable.")))
        runOnWorker(callback) { helper.read(key) }
    }

    override fun secureDelete(key: String, callback: (Result<Unit>) -> Unit) {
        val helper = secureStorageHelper
            ?: return callback(Result.failure(IllegalStateException("Secure storage is unavailable.")))
        runOnWorker(callback) { helper.delete(key) }
    }

    override fun secureClearAll(callback: (Result<Unit>) -> Unit) {
        val helper = secureStorageHelper
            ?: return callback(Result.failure(IllegalStateException("Secure storage is unavailable.")))
        runOnWorker(callback) { helper.clearAll() }
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
        registerForegroundLifecycleTracker()
        registerScreenCaptureCallback()
        applyProtectionState()
        emitForegroundState(currentForegroundState())
    }

    private fun releaseActivity() {
        unregisterScreenCaptureCallback()
        unregisterForegroundLifecycleTracker()
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

    private fun registerForegroundLifecycleTracker() {
        val activeActivity = activity ?: return
        if (foregroundLifecycleTracker != null) {
            return
        }
        val tracker = ForegroundLifecycleTracker(
            targetActivity = { activity },
            onForegroundChanged = ::emitForegroundState
        )
        activeActivity.application.registerActivityLifecycleCallbacks(tracker)
        foregroundLifecycleTracker = tracker
    }

    private fun unregisterForegroundLifecycleTracker() {
        val activeActivity = activity ?: return
        val tracker = foregroundLifecycleTracker ?: return
        activeActivity.application.unregisterActivityLifecycleCallbacks(tracker)
        foregroundLifecycleTracker = null
    }

    private fun emitOverlayViolation() = flutterApi?.onOverlayViolation {}

    private fun emitForegroundState(active: Boolean) {
        flutterApi?.onForegroundStateChanged(active) {}
    }

    private fun currentForegroundState(): Boolean {
        val activeActivity = activity ?: return true
        return foregroundLifecycleTracker?.isForeground
            ?: (!activeActivity.isFinishing && !activeActivity.isDestroyed)
    }

    private fun <T> runOnWorker(callback: (Result<T>) -> Unit, operation: () -> T) {
        val executor = detectorExecutor
            ?: return callback(Result.failure(IllegalStateException("Background worker is unavailable.")))
        try {
            executor.execute { callback(runCatching(operation)) }
        } catch (error: RejectedExecutionException) {
            callback(Result.failure(error))
        }
    }
}
