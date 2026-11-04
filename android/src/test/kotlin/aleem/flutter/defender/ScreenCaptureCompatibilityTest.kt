package aleem.flutter.defender

import android.app.Activity
import kotlin.test.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.verifyNoInteractions

class ScreenCaptureCompatibilityTest {
    @Test
    fun `teardown does not resolve the Android 14 callback on older Android`() {
        val pluginName = FlutterDefenderPlugin::class.java.name
        val parentLoader = FlutterDefenderPlugin::class.java.classLoader!!
        // Model a pre-34 runtime where the callback class does not exist.
        val legacyLoader = object : ClassLoader(parentLoader) {
            override fun loadClass(name: String, resolve: Boolean): Class<*> {
                if (name == "android.app.Activity\$ScreenCaptureCallback") {
                    throw ClassNotFoundException(name)
                }
                if (name != pluginName && !name.startsWith(pluginName + "$")) {
                    return super.loadClass(name, resolve)
                }
                val loaded = findLoadedClass(name) ?: run {
                    val path = name.replace('.', '/') + ".class"
                    val bytes = parentLoader.getResourceAsStream(path)!!.use { it.readBytes() }
                    defineClass(name, bytes, 0, bytes.size)
                }
                if (resolve) resolveClass(loaded)
                return loaded
            }
        }
        val pluginClass = legacyLoader.loadClass(pluginName)
        val plugin = pluginClass.getDeclaredConstructor().newInstance()
        val activity = mock(Activity::class.java)
        pluginClass.getDeclaredField("activity").apply {
            isAccessible = true
            set(plugin, activity)
        }
        pluginClass.getDeclaredField("screenCaptureCallbackHandle").apply {
            isAccessible = true
            set(plugin, Any())
        }

        // Android's JVM test stubs report SDK_INT = 0 (below API 34).
        pluginClass.getDeclaredMethod("unregisterScreenCaptureCallback").apply {
            isAccessible = true
            invoke(plugin)
        }

        verifyNoInteractions(activity)
    }
}
