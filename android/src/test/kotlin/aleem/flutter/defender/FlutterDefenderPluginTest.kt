package aleem.flutter.defender

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class FlutterDefenderPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = FlutterDefenderPlugin()
        val result = CapturingResult()

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)

        assertEquals("Android ${android.os.Build.VERSION.RELEASE}", result.successValue)
    }

    @Test
    fun onMethodCall_setFlagSecure_forwardsToPlatformBridge() {
        val bridge = FakeAndroidPlatformBridge()
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val activity = TestActivity()
        val result = CapturingResult()

        plugin.attachForTesting(activity = activity)
        plugin.onMethodCall(
            MethodCall("setFlagSecure", mapOf("enabled" to true)),
            result
        )

        assertEquals(listOf(true), bridge.flagSecureCalls)
        assertNull(result.successValue)
    }

    @Test
    fun onMethodCall_isOverlayPermissionDetected_returnsBridgeValue() {
        val bridge = FakeAndroidPlatformBridge(overlayDetected = true)
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val result = CapturingResult()

        plugin.attachForTesting()
        plugin.onMethodCall(MethodCall("isOverlayPermissionDetected", null), result)

        assertEquals(true, result.successValue)
    }

    @Test
    fun onMethodCall_isAppInForeground_returnsBridgeValue() {
        val bridge = FakeAndroidPlatformBridge(appInForeground = false)
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val result = CapturingResult()

        plugin.attachForTesting()
        plugin.onMethodCall(MethodCall("isAppInForeground", null), result)

        assertEquals(false, result.successValue)
    }

    @Test
    fun onMethodCall_isEmulator_returnsBridgeValue() {
        val bridge = FakeAndroidPlatformBridge(emulator = true)
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val result = CapturingResult()

        plugin.onMethodCall(MethodCall("isEmulator", null), result)

        assertEquals(true, result.successValue)
    }

    @Test
    fun onMethodCall_isScreenCaptured_returnsFalse() {
        val plugin = FlutterDefenderPlugin()
        val result = CapturingResult()

        plugin.onMethodCall(MethodCall("isScreenCaptured", null), result)

        assertEquals(false, result.successValue)
    }

    @Test
    fun activityAttach_registersScreenshotCallback_andDetachingUnregistersIt() {
        val bridge = FakeAndroidPlatformBridge()
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val activity = TestActivity()
        val invoker = FakeMethodInvoker()

        plugin.attachForTesting()
        plugin.setMethodInvokerForTesting(invoker)
        plugin.onActivityAttachedForTesting(activity)

        assertEquals(activity, bridge.registeredActivity)
        assertTrue(bridge.registeredHandle != null)

        bridge.emitScreenshotAttempt()

        assertEquals(listOf("onScreenshotAttempted"), invoker.invokedMethods)

        plugin.onActivityDetachedForTesting()

        assertEquals(activity, bridge.unregisteredActivity)
        assertEquals(bridge.registeredHandle, bridge.unregisteredHandle)
    }

    @Test
    fun activityAttach_doesNotRegisterTwiceWhileStillAttached() {
        val bridge = FakeAndroidPlatformBridge()
        val plugin = FlutterDefenderPlugin(platformBridge = bridge)
        val activity = TestActivity()

        plugin.attachForTesting()
        plugin.onActivityAttachedForTesting(activity)
        plugin.onActivityAttachedForTesting(activity)

        assertEquals(1, bridge.registerCallCount)
    }
}

private class TestActivity : Activity()

private class CapturingResult : MethodChannel.Result {
    var successValue: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var notImplemented = false

    override fun success(result: Any?) {
        successValue = result
    }

    override fun error(
        errorCode: String,
        errorMessage: String?,
        errorDetails: Any?
    ) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }

    override fun notImplemented() {
        notImplemented = true
    }
}

private class FakeMethodInvoker : FlutterDefenderMethodInvoker {
    val invokedMethods = mutableListOf<String>()

    override fun invokeMethod(
        method: String,
        arguments: Any?
    ) {
        invokedMethods += method
    }
}

private class FakeAndroidPlatformBridge(
    private val overlayDetected: Boolean = false,
    private val appInForeground: Boolean = true,
    private val emulator: Boolean = false
) : AndroidPlatformBridge {
    val flagSecureCalls = mutableListOf<Boolean>()
    var registerCallCount = 0
    var registeredActivity: Activity? = null
    var unregisteredActivity: Activity? = null
    var registeredHandle: Any? = null
    var unregisteredHandle: Any? = null
    private var screenshotAttempted: (() -> Unit)? = null

    override fun setFlagSecure(
        activity: Activity,
        enabled: Boolean
    ) {
        flagSecureCalls += enabled
    }

    override fun isOverlayPermissionDetected(context: Context?): Boolean = overlayDetected

    override fun isAppInForeground(context: Context?): Boolean = appInForeground

    override fun isEmulator(): Boolean = emulator

    override fun registerScreenCaptureCallback(
        activity: Activity,
        onScreenshotAttempted: () -> Unit
    ): Any {
        registerCallCount += 1
        registeredActivity = activity
        screenshotAttempted = onScreenshotAttempted
        return Any().also { registeredHandle = it }
    }

    override fun unregisterScreenCaptureCallback(
        activity: Activity,
        callbackHandle: Any
    ) {
        unregisteredActivity = activity
        unregisteredHandle = callbackHandle
    }

    fun emitScreenshotAttempt() {
        screenshotAttempted?.invoke()
    }
}
