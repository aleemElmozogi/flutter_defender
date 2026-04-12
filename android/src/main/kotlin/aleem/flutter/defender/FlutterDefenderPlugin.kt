package aleem.flutter.defender

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

internal interface FlutterDefenderMethodInvoker {
    fun invokeMethod(
        method: String,
        arguments: Any?
    )
}

internal class MethodChannelInvoker(
    private val channel: MethodChannel
) : FlutterDefenderMethodInvoker {
    override fun invokeMethod(
        method: String,
        arguments: Any?
    ) {
        channel.invokeMethod(method, arguments)
    }
}

internal interface AndroidPlatformBridge {
    fun setFlagSecure(
        activity: Activity,
        enabled: Boolean
    )

    fun isOverlayPermissionDetected(context: Context?): Boolean

    fun isAppInForeground(context: Context?): Boolean

    fun isEmulator(): Boolean

    fun registerScreenCaptureCallback(
        activity: Activity,
        onScreenshotAttempted: () -> Unit
    ): Any?

    fun unregisterScreenCaptureCallback(
        activity: Activity,
        callbackHandle: Any
    )
}

internal class DefaultAndroidPlatformBridge : AndroidPlatformBridge {
    override fun setFlagSecure(
        activity: Activity,
        enabled: Boolean
    ) {
        activity.runOnUiThread {
            if (enabled) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    override fun isOverlayPermissionDetected(context: Context?): Boolean {
        context ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            false
        }
    }

    override fun isAppInForeground(context: Context?): Boolean {
        context ?: return true
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return true
        val appProcesses = activityManager.runningAppProcesses ?: return false
        return appProcesses.any { appProcess ->
            appProcess.importance ==
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                appProcess.processName == context.packageName
        }
    }

    override fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.MODEL.contains("google_sdk")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
            || "google_sdk" == Build.PRODUCT
            || Build.PRODUCT.contains("sdk")
            || Build.PRODUCT.contains("emulator")
            || Build.HARDWARE.contains("goldfish")
            || Build.HARDWARE.contains("ranchu"))
    }

    override fun registerScreenCaptureCallback(
        activity: Activity,
        onScreenshotAttempted: () -> Unit
    ): Any? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return null
        }
        val callback = Activity.ScreenCaptureCallback {
            onScreenshotAttempted()
        }
        activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
        return callback
    }

    override fun unregisterScreenCaptureCallback(
        activity: Activity,
        callbackHandle: Any
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        val callback = callbackHandle as? Activity.ScreenCaptureCallback ?: return
        activity.unregisterScreenCaptureCallback(callback)
    }
}

/** FlutterDefenderPlugin */
class FlutterDefenderPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler {
    private val platformBridge: AndroidPlatformBridge
    private var methodInvoker: FlutterDefenderMethodInvoker?
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var screenCaptureCallbackHandle: Any? = null

    constructor() : this(DefaultAndroidPlatformBridge(), null)

    internal constructor(
        platformBridge: AndroidPlatformBridge,
        methodInvoker: FlutterDefenderMethodInvoker? = null
    ) {
        this.platformBridge = platformBridge
        this.methodInvoker = methodInvoker
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_defender")
        methodInvoker = MethodChannelInvoker(channel)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "setFlagSecure" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setFlagSecure(enabled)
                result.success(null)
            }
            "isOverlayPermissionDetected" -> {
                result.success(
                    platformBridge.isOverlayPermissionDetected(activity ?: applicationContext)
                )
            }
            "isAppInForeground" ->
                result.success(platformBridge.isAppInForeground(applicationContext))
            "isEmulator" -> result.success(platformBridge.isEmulator())
            "isScreenCaptured" -> result.success(false)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterScreenCaptureCallback()
        if (::channel.isInitialized) {
            channel.setMethodCallHandler(null)
        }
        applicationContext = null
        methodInvoker = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerScreenCaptureCallback()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterScreenCaptureCallback()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerScreenCaptureCallback()
    }

    override fun onDetachedFromActivity() {
        unregisterScreenCaptureCallback()
        activity = null
    }

    internal fun attachForTesting(
        applicationContext: Context? = null,
        activity: Activity? = null
    ) {
        this.applicationContext = applicationContext
        this.activity = activity
    }

    internal fun onActivityAttachedForTesting(activity: Activity) {
        this.activity = activity
        registerScreenCaptureCallback()
    }

    internal fun onActivityDetachedForTesting() {
        unregisterScreenCaptureCallback()
        activity = null
    }

    internal fun setMethodInvokerForTesting(methodInvoker: FlutterDefenderMethodInvoker?) {
        this.methodInvoker = methodInvoker
    }

    private fun setFlagSecure(enabled: Boolean) {
        val activeActivity = activity ?: return
        platformBridge.setFlagSecure(activeActivity, enabled)
    }

    private fun registerScreenCaptureCallback() {
        val activeActivity = activity ?: return
        if (screenCaptureCallbackHandle != null) {
            return
        }
        screenCaptureCallbackHandle =
            platformBridge.registerScreenCaptureCallback(activeActivity) {
                methodInvoker?.invokeMethod("onScreenshotAttempted", null)
            }
    }

    private fun unregisterScreenCaptureCallback() {
        val activeActivity = activity
        val callbackHandle = screenCaptureCallbackHandle
        if (activeActivity != null && callbackHandle != null) {
            platformBridge.unregisterScreenCaptureCallback(activeActivity, callbackHandle)
        }
        screenCaptureCallbackHandle = null
    }
}
