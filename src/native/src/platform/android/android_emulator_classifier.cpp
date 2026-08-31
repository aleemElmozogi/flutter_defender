#include "android_emulator_classifier.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <string>

namespace flutter_defender::platform_internal {
namespace {

std::string ToLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return value;
}

bool HasPrefix(const std::string& value, const char* prefix) {
  return value.rfind(prefix, 0) == 0;
}

bool Contains(const std::string& value, const char* token) {
  return value.find(token) != std::string::npos;
}

template <size_t ValueCount, size_t TokenCount>
bool ContainsAnyToken(
    const std::array<std::string, ValueCount>& values,
    const std::array<const char*, TokenCount>& tokens) {
  return std::any_of(values.begin(), values.end(), [&](const std::string& value) {
    return std::any_of(tokens.begin(), tokens.end(), [&](const char* token) {
      return Contains(value, token);
    });
  });
}

}  // namespace

bool IsAndroidEmulator(const AndroidBuildIdentity& identity) {
  const std::string fingerprint = ToLower(identity.fingerprint);
  const std::string model = ToLower(identity.model);
  const std::string manufacturer = ToLower(identity.manufacturer);
  const std::string brand = ToLower(identity.brand);
  const std::string device = ToLower(identity.device);
  const std::string product = ToLower(identity.product);
  const std::string hardware = ToLower(identity.hardware);
  const std::array<std::string, 7> values = {
      fingerprint,
      model,
      manufacturer,
      brand,
      device,
      product,
      hardware,
  };
  static constexpr std::array<const char*, 3> kDesktopEmulatorTokens = {
      "memu",
      "microvirt",
      "vbox86",
  };

  return HasPrefix(fingerprint, "generic") ||
         HasPrefix(fingerprint, "unknown") ||
         Contains(model, "google_sdk") || Contains(model, "emulator") ||
         Contains(model, "android sdk built for x86") ||
         Contains(manufacturer, "genymotion") ||
         (HasPrefix(brand, "generic") && HasPrefix(device, "generic")) ||
         product == "google_sdk" || Contains(product, "sdk") ||
         Contains(product, "emulator") || Contains(hardware, "goldfish") ||
         Contains(hardware, "ranchu") ||
         ContainsAnyToken(values, kDesktopEmulatorTokens);
}

}  // namespace flutter_defender::platform_internal
