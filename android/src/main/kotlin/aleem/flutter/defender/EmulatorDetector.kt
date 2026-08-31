package aleem.flutter.defender

import android.os.Build
import java.util.Locale

internal data class AndroidBuildIdentity(
    val fingerprint: String,
    val model: String,
    val manufacturer: String,
    val brand: String,
    val device: String,
    val product: String,
    val hardware: String
) {
    companion object {
        fun current(): AndroidBuildIdentity = AndroidBuildIdentity(
            fingerprint = Build.FINGERPRINT,
            model = Build.MODEL,
            manufacturer = Build.MANUFACTURER,
            brand = Build.BRAND,
            device = Build.DEVICE,
            product = Build.PRODUCT,
            hardware = Build.HARDWARE
        )
    }
}

internal object AndroidEmulatorClassifier {
    private val desktopEmulatorTokens = listOf(
        "memu",
        "microvirt",
        "vbox86"
    )

    fun isEmulator(identity: AndroidBuildIdentity): Boolean {
        val fingerprint = identity.fingerprint.normalized()
        val model = identity.model.normalized()
        val manufacturer = identity.manufacturer.normalized()
        val brand = identity.brand.normalized()
        val device = identity.device.normalized()
        val product = identity.product.normalized()
        val hardware = identity.hardware.normalized()

        return fingerprint.startsWith("generic") ||
            fingerprint.startsWith("unknown") ||
            model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for x86") ||
            manufacturer.contains("genymotion") ||
            (brand.startsWith("generic") && device.startsWith("generic")) ||
            product == "google_sdk" ||
            product.contains("sdk") ||
            product.contains("emulator") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            listOf(fingerprint, model, manufacturer, brand, device, product, hardware)
                .any { value -> desktopEmulatorTokens.any(value::contains) }
    }

    private fun String.normalized(): String = lowercase(Locale.ROOT)
}

object EmulatorDetector {
    fun isEmulator(): Boolean = AndroidEmulatorClassifier.isEmulator(
        AndroidBuildIdentity.current()
    )
}
