#include "../platform_detector_internal.h"

#if defined(__ANDROID__)

#include <sys/system_properties.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

namespace flutter_defender::platform_internal {
namespace {

bool FileExists(const char* path) {
  std::ifstream file(path);
  return file.good();
}

bool HasPrefix(const std::string& value, const char* prefix) {
  return value.rfind(prefix, 0) == 0;
}

std::string ToLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return value;
}

bool ContainsCaseInsensitive(const std::string& haystack, const char* needle) {
  return ToLower(haystack).find(ToLower(needle)) != std::string::npos;
}

template <size_t Size>
bool AnyFileExists(const std::array<const char*, Size>& paths) {
  return std::any_of(paths.begin(), paths.end(), FileExists);
}

template <size_t Size>
bool ContainsAnyToken(
    const std::string& value,
    const std::array<const char*, Size>& tokens) {
  return std::any_of(tokens.begin(), tokens.end(), [&](const char* token) {
    return ContainsCaseInsensitive(value, token);
  });
}

std::string AndroidProperty(const char* name) {
  char value[PROP_VALUE_MAX] = {0};
  __system_property_get(name, value);
  return std::string(value);
}

bool IsProcessTraced() {
  std::ifstream status("/proc/self/status");
  std::string line;
  while (std::getline(status, line)) {
    if (HasPrefix(line, "TracerPid:")) {
      std::istringstream stream(line.substr(std::strlen("TracerPid:")));
      int tracer_pid = 0;
      stream >> tracer_pid;
      return tracer_pid > 0;
    }
  }
  return false;
}

bool HasReadWriteSensitiveMount(const std::string& mount_line) {
  const bool sensitive_path =
      mount_line.find(" /system ") != std::string::npos ||
      mount_line.find(" /vendor ") != std::string::npos ||
      mount_line.find(" /product ") != std::string::npos ||
      mount_line.find(" /system_ext ") != std::string::npos;
  const bool read_write = mount_line.find(" rw,") != std::string::npos ||
                          mount_line.find(",rw,") != std::string::npos ||
                          mount_line.find(",rw ") != std::string::npos;
  return sensitive_path && read_write;
}

bool AndroidMountsShowRoot() {
  static constexpr std::array<const char*, 4> kRootMountTokens = {
      "magisk",
      "kernelsu",
      "apatch",
      "overlay",
  };

  std::ifstream mounts("/proc/mounts");
  std::string line;
  while (std::getline(mounts, line)) {
    if (ContainsAnyToken(line, kRootMountTokens) ||
        HasReadWriteSensitiveMount(line)) {
      return true;
    }
  }
  return false;
}

}  // namespace

bool IsDebuggerAttachedImpl() {
  return IsProcessTraced();
}

bool IsRootedOrJailbrokenImpl() {
  static constexpr std::array<const char*, 21> kRootPaths = {
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
      "/sbin/.magisk",
      "/debug_ramdisk/su",
      "/data/adb/ksu",
      "/data/adb/ap",
      "/system/bin/ksud",
  };

  return AnyFileExists(kRootPaths) ||
         AndroidProperty("ro.build.tags").find("test-keys") !=
             std::string::npos ||
         AndroidMountsShowRoot();
}

bool IsEmulatorImpl() {
  const std::string fingerprint = AndroidProperty("ro.build.fingerprint");
  const std::string model = AndroidProperty("ro.product.model");
  const std::string manufacturer = AndroidProperty("ro.product.manufacturer");
  const std::string brand = AndroidProperty("ro.product.brand");
  const std::string device = AndroidProperty("ro.product.device");
  const std::string product = AndroidProperty("ro.product.name");
  const std::string hardware = AndroidProperty("ro.hardware");

  return HasPrefix(fingerprint, "generic") ||
         HasPrefix(fingerprint, "unknown") ||
         ContainsCaseInsensitive(model, "google_sdk") ||
         ContainsCaseInsensitive(model, "emulator") ||
         ContainsCaseInsensitive(model, "Android SDK built for x86") ||
         ContainsCaseInsensitive(manufacturer, "Genymotion") ||
         (HasPrefix(brand, "generic") && HasPrefix(device, "generic")) ||
         product == "google_sdk" || ContainsCaseInsensitive(product, "sdk") ||
         ContainsCaseInsensitive(product, "emulator") ||
         ContainsCaseInsensitive(hardware, "goldfish") ||
         ContainsCaseInsensitive(hardware, "ranchu");
}

bool IsTamperedImpl() {
  static constexpr std::array<const char*, 5> kHookingPaths = {
      "/data/local/tmp/frida-server",
      "/data/local/tmp/re.frida.server",
      "/system/lib/libsubstrate.so",
      "/system/lib64/libsubstrate.so",
      "/data/local/tmp/XposedBridge.jar",
  };
  static constexpr std::array<const char*, 3> kMapTokens = {
      "frida",
      "xposed",
      "substrate",
  };

  if (IsProcessTraced() || AnyFileExists(kHookingPaths)) {
    return true;
  }

  std::ifstream maps("/proc/self/maps");
  std::string line;
  while (std::getline(maps, line)) {
    if (ContainsAnyToken(line, kMapTokens)) {
      return true;
    }
  }
  return false;
}

}  // namespace flutter_defender::platform_internal

#endif  // defined(__ANDROID__)
