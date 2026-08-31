#include "android_emulator_classifier.h"

#include <iostream>
#include <string>

namespace {

using flutter_defender::platform_internal::AndroidBuildIdentity;
using flutter_defender::platform_internal::IsAndroidEmulator;

AndroidBuildIdentity PhysicalIdentity() {
  return AndroidBuildIdentity{
      "google/husky/husky:15/AP4A.250205.002/1234567:user/release-keys",
      "Pixel 8 Pro",
      "Google",
      "google",
      "husky",
      "husky",
      "husky",
  };
}

bool Expect(const std::string& name, bool actual, bool expected) {
  if (actual == expected) {
    return true;
  }
  std::cerr << name << " failed: expected " << expected << ", got " << actual
            << '\n';
  return false;
}

}  // namespace

int main() {
  bool passed = true;

  AndroidBuildIdentity memu = PhysicalIdentity();
  memu.model = "MEmu";
  passed &= Expect("MEmu identity", IsAndroidEmulator(memu), true);

  AndroidBuildIdentity microvirt = PhysicalIdentity();
  microvirt.manufacturer = "Microvirt";
  passed &= Expect("Microvirt identity", IsAndroidEmulator(microvirt), true);

  AndroidBuildIdentity virtualbox = PhysicalIdentity();
  virtualbox.hardware = "VBOX86";
  passed &= Expect("MEmu VirtualBox hardware", IsAndroidEmulator(virtualbox), true);

  AndroidBuildIdentity avd = PhysicalIdentity();
  avd.fingerprint = "generic/sdk_gphone64_arm64/emu64a:15/test-keys";
  avd.hardware = "ranchu";
  passed &= Expect("Android Virtual Device", IsAndroidEmulator(avd), true);

  passed &= Expect(
      "physical production identity", IsAndroidEmulator(PhysicalIdentity()), false);

  return passed ? 0 : 1;
}
