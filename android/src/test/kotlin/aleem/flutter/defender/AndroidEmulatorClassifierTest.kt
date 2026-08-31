package aleem.flutter.defender

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AndroidEmulatorClassifierTest {
    @Test
    fun `detects memu model identity`() {
        assertTrue(
            AndroidEmulatorClassifier.isEmulator(
                physicalIdentity.copy(model = "MEmu")
            )
        )
    }

    @Test
    fun `detects microvirt manufacturer identity`() {
        assertTrue(
            AndroidEmulatorClassifier.isEmulator(
                physicalIdentity.copy(manufacturer = "Microvirt")
            )
        )
    }

    @Test
    fun `detects memu virtualbox hardware case insensitively`() {
        assertTrue(
            AndroidEmulatorClassifier.isEmulator(
                physicalIdentity.copy(hardware = "VBOX86")
            )
        )
    }

    @Test
    fun `preserves standard android emulator detection`() {
        assertTrue(
            AndroidEmulatorClassifier.isEmulator(
                physicalIdentity.copy(
                    fingerprint = "generic/sdk_gphone64_arm64/emu64a:15/test-keys",
                    hardware = "ranchu"
                )
            )
        )
    }

    @Test
    fun `does not classify a physical production identity as emulator`() {
        assertFalse(AndroidEmulatorClassifier.isEmulator(physicalIdentity))
    }

    private companion object {
        val physicalIdentity = AndroidBuildIdentity(
            fingerprint = "google/husky/husky:15/AP4A.250205.002/1234567:user/release-keys",
            model = "Pixel 8 Pro",
            manufacturer = "Google",
            brand = "google",
            device = "husky",
            product = "husky",
            hardware = "husky"
        )
    }
}
