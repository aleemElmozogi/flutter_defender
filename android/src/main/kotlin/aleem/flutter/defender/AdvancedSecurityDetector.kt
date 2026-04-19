package aleem.flutter.defender

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Debug
import java.io.File
import java.net.NetworkInterface

internal class AdvancedSecurityDetector(private val context: Context) {
    fun collectSignals(): AdvancedSecuritySignals {
        val rooted = isRooted()
        val proxyEnabled = isProxyEnabled()
        val vpnEnabled = isVpnEnabled()
        val debuggerAttached = Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        val tamperingDetected = isHookingDetected()
        val tamperingDetails = buildList {
            if (debuggerAttached) add("debugger")
            if (tamperingDetected) add("hooking")
        }.joinToString(",").ifBlank { null }

        return AdvancedSecuritySignals(
            rootedOrJailbroken = rooted,
            proxyEnabled = proxyEnabled,
            vpnEnabled = vpnEnabled,
            debuggerAttached = debuggerAttached,
            tamperingDetected = tamperingDetected,
            tamperingDetails = tamperingDetails
        )
    }

    private fun isRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) {
            return true
        }
        val knownPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su",
            "/cache/su",
            "/data/su",
            "/dev/com.koushikdutta.superuser.daemon/",
            "/system/xbin/daemonsu",
            "/data/adb/magisk",
            "/sbin/.magisk"
        )
        if (knownPaths.any { File(it).exists() }) {
            return true
        }
        return canExecuteSu()
    }

    private fun canExecuteSu(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val output = process.inputStream.bufferedReader().use { it.readText() }
            output.isNotBlank()
        } catch (_: Throwable) {
            false
        }
    }

    private fun isProxyEnabled(): Boolean {
        val proxyHost = System.getProperty("http.proxyHost")
        val proxyPort = System.getProperty("http.proxyPort")
        return !proxyHost.isNullOrBlank() && proxyPort != null && proxyPort != "-1"
    }

    private fun isVpnEnabled(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val activeNetwork = cm?.activeNetwork
        val capabilities = activeNetwork?.let { cm.getNetworkCapabilities(it) }
        if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
            return true
        }
        return try {
            NetworkInterface.getNetworkInterfaces().toList().any { intf ->
                intf.isUp && (intf.name.startsWith("tun") || intf.name.startsWith("ppp"))
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun isHookingDetected(): Boolean {
        if (isXposedPresent()) {
            return true
        }
        if (containsFridaArtifacts()) {
            return true
        }
        val suspiciousPaths = listOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/system/lib/libsubstrate.so",
            "/system/lib64/libsubstrate.so",
            "/data/local/tmp/XposedBridge.jar"
        )
        return suspiciousPaths.any { File(it).exists() }
    }

    private fun isXposedPresent(): Boolean {
        return try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun containsFridaArtifacts(): Boolean {
        return try {
            val maps = File("/proc/self/maps")
            if (!maps.exists()) {
                return false
            }
            maps.useLines { lines ->
                lines.any { line ->
                    line.contains("frida", ignoreCase = true) ||
                        line.contains("xposed", ignoreCase = true) ||
                        line.contains("substrate", ignoreCase = true)
                }
            }
        } catch (_: Throwable) {
            false
        }
    }
}
