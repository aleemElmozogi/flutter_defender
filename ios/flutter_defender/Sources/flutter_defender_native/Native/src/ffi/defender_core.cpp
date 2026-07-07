#include <cstdint>
#include <cstdlib>

#include <flutter_defender/defender_crypto.h>
#include <flutter_defender/defender_platform.h>

#define FLUTTER_DEFENDER_EXPORT __attribute__((visibility("default")))

extern "C" {

FLUTTER_DEFENDER_EXPORT int32_t fd_native_is_debugger_attached() {
  return flutter_defender::IsDebuggerAttached() ? 1 : 0;
}

FLUTTER_DEFENDER_EXPORT int32_t fd_native_is_rooted_or_jailbroken() {
  return flutter_defender::IsRootedOrJailbroken() ? 1 : 0;
}

FLUTTER_DEFENDER_EXPORT int32_t fd_native_is_emulator() {
  return flutter_defender::IsEmulator() ? 1 : 0;
}

FLUTTER_DEFENDER_EXPORT int32_t fd_native_is_tampered() {
  return flutter_defender::IsTampered() ? 1 : 0;
}

FLUTTER_DEFENDER_EXPORT char* fd_native_hmac_sha256_hex(
    const uint8_t* data,
    int32_t data_length,
    const uint8_t* key,
    int32_t key_length) {
  if ((data == nullptr && data_length > 0) || key == nullptr ||
      data_length < 0 || key_length <= 0) {
    return nullptr;
  }

  const flutter_defender::Digest digest = flutter_defender::HmacSha256(
      data,
      static_cast<size_t>(data_length),
      key,
      static_cast<size_t>(key_length));
  return flutter_defender::CopyHexDigest(digest);
}

FLUTTER_DEFENDER_EXPORT void fd_native_free_string(char* value) {
  std::free(value);
}

}  // extern "C"
