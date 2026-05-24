#ifndef FLUTTER_DEFENDER_CRYPTO_H_
#define FLUTTER_DEFENDER_CRYPTO_H_

#include <array>
#include <cstddef>
#include <cstdint>

namespace flutter_defender {

constexpr int kDigestSize = 32;
using Digest = std::array<uint8_t, kDigestSize>;

Digest HmacSha256(
    const uint8_t* data,
    size_t data_length,
    const uint8_t* key,
    size_t key_length);

char* CopyHexDigest(const Digest& digest);

}  // namespace flutter_defender

#endif  // FLUTTER_DEFENDER_CRYPTO_H_
