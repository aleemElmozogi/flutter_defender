#ifndef FLUTTER_DEFENDER_NATIVE_H_
#define FLUTTER_DEFENDER_NATIVE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int32_t fd_native_is_debugger_attached(void);
int32_t fd_native_is_rooted_or_jailbroken(void);
int32_t fd_native_is_emulator(void);
int32_t fd_native_is_tampered(void);
char* fd_native_hmac_sha256_hex(
    const uint8_t* data,
    int32_t data_length,
    const uint8_t* key,
    int32_t key_length);
void fd_native_free_string(char* value);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // FLUTTER_DEFENDER_NATIVE_H_
