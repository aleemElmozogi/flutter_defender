#include "../platform_detector_internal.h"

#if defined(__APPLE__)

#include <TargetConditionals.h>
#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>

namespace flutter_defender::platform_internal {
namespace {

bool FileExists(const char* path) {
  std::ifstream file(path);
  return file.good();
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

bool AppleDebuggerAttached() {
  kinfo_proc info;
  std::memset(&info, 0, sizeof(info));

  size_t size = sizeof(info);
  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
  if (sysctl(mib, 4, &info, &size, nullptr, 0) != 0) {
    return false;
  }
  return (info.kp_proc.p_flag & P_TRACED) != 0;
}

bool CanWriteOutsideAppleSandbox() {
  constexpr const char* kProbePath = "/private/flutter_defender_jb_check.txt";
  FILE* test_file = std::fopen(kProbePath, "w");
  if (test_file == nullptr) {
    return false;
  }

  std::fclose(test_file);
  std::remove(kProbePath);
  return true;
}

bool HasSuspiciousDyldEnvironment() {
  static constexpr std::array<const char*, 3> kDyldEnvironmentKeys = {
      "DYLD_INSERT_LIBRARIES",
      "DYLD_LIBRARY_PATH",
      "DYLD_FRAMEWORK_PATH",
  };

  return std::any_of(
      kDyldEnvironmentKeys.begin(),
      kDyldEnvironmentKeys.end(),
      [](const char* key) {
        const char* value = std::getenv(key);
        return value != nullptr && std::strlen(value) > 0;
      });
}

bool HasSuspiciousLoadedImage() {
  static constexpr std::array<const char*, 8> kImageTokens = {
      "frida",
      "gadget",
      "substrate",
      "substitute",
      "libhooker",
      "cycript",
      "sslkill",
      "flex",
  };

  for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
    const char* image_name = _dyld_get_image_name(i);
    if (image_name != nullptr &&
        ContainsAnyToken(std::string(image_name), kImageTokens)) {
      return true;
    }
  }
  return false;
}

}  // namespace

bool IsDebuggerAttachedImpl() {
  return AppleDebuggerAttached();
}

bool IsRootedOrJailbrokenImpl() {
#if TARGET_OS_SIMULATOR
  return false;
#else
  static constexpr std::array<const char*, 13> kJailbreakPaths = {
      "/Applications/Cydia.app",
      "/Applications/Sileo.app",
      "/Applications/Zebra.app",
      "/Library/MobileSubstrate/MobileSubstrate.dylib",
      "/bin/bash",
      "/usr/sbin/sshd",
      "/etc/apt",
      "/private/var/lib/apt/",
      "/private/var/stash",
      "/private/var/jb",
      "/var/jb",
      "/usr/lib/libjailbreak.dylib",
      "/usr/lib/libsubstitute.dylib",
  };

  return AnyFileExists(kJailbreakPaths) || CanWriteOutsideAppleSandbox();
#endif
}

bool IsEmulatorImpl() {
#if TARGET_OS_SIMULATOR
  return true;
#else
  return false;
#endif
}

bool IsTamperedImpl() {
  return AppleDebuggerAttached() || HasSuspiciousDyldEnvironment() ||
         HasSuspiciousLoadedImage();
}

}  // namespace flutter_defender::platform_internal

#endif  // defined(__APPLE__)
