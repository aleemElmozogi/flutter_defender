#include <flutter_defender/defender_crypto.h>

#include <cstdlib>
#include <vector>

namespace flutter_defender {
namespace {

constexpr int kSha256BlockSize = 64;

class Sha256 {
 public:
  Sha256() { Reset(); }

  void Update(const uint8_t* data, size_t length) {
    for (size_t i = 0; i < length; ++i) {
      data_[data_length_++] = data[i];
      if (data_length_ == kSha256BlockSize) {
        Transform();
        bit_length_ += kSha256BlockSize * 8;
        data_length_ = 0;
      }
    }
  }

  Digest Final() {
    PadMessage();
    Transform();

    Digest hash{};
    for (uint32_t i = 0; i < 4; ++i) {
      hash[i] = (state_[0] >> (24 - i * 8)) & 0xff;
      hash[i + 4] = (state_[1] >> (24 - i * 8)) & 0xff;
      hash[i + 8] = (state_[2] >> (24 - i * 8)) & 0xff;
      hash[i + 12] = (state_[3] >> (24 - i * 8)) & 0xff;
      hash[i + 16] = (state_[4] >> (24 - i * 8)) & 0xff;
      hash[i + 20] = (state_[5] >> (24 - i * 8)) & 0xff;
      hash[i + 24] = (state_[6] >> (24 - i * 8)) & 0xff;
      hash[i + 28] = (state_[7] >> (24 - i * 8)) & 0xff;
    }
    return hash;
  }

 private:
  static uint32_t RotateRight(uint32_t value, uint32_t shift) {
    return (value >> shift) | (value << (32 - shift));
  }

  static uint32_t Choose(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (~x & z);
  }

  static uint32_t Majority(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (x & z) ^ (y & z);
  }

  static uint32_t Sigma0(uint32_t value) {
    return RotateRight(value, 2) ^ RotateRight(value, 13) ^
           RotateRight(value, 22);
  }

  static uint32_t Sigma1(uint32_t value) {
    return RotateRight(value, 6) ^ RotateRight(value, 11) ^
           RotateRight(value, 25);
  }

  static uint32_t Gamma0(uint32_t value) {
    return RotateRight(value, 7) ^ RotateRight(value, 18) ^ (value >> 3);
  }

  static uint32_t Gamma1(uint32_t value) {
    return RotateRight(value, 17) ^ RotateRight(value, 19) ^ (value >> 10);
  }

  void Reset() {
    data_.fill(0);
    data_length_ = 0;
    bit_length_ = 0;
    state_ = {
        0x6a09e667,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    };
  }

  void PadMessage() {
    uint32_t i = data_length_;

    if (data_length_ < 56) {
      data_[i++] = 0x80;
      while (i < 56) {
        data_[i++] = 0x00;
      }
    } else {
      data_[i++] = 0x80;
      while (i < kSha256BlockSize) {
        data_[i++] = 0x00;
      }
      Transform();
      data_.fill(0);
    }

    bit_length_ += data_length_ * 8;
    for (int offset = 0; offset < 8; ++offset) {
      data_[63 - offset] = bit_length_ >> (offset * 8);
    }
  }

  void Transform() {
    static constexpr std::array<uint32_t, 64> kRoundConstants = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b,
        0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01,
        0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7,
        0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152,
        0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
        0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819,
        0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08,
        0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f,
        0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

    std::array<uint32_t, 64> schedule{};
    for (uint32_t i = 0, j = 0; i < 16; ++i, j += 4) {
      schedule[i] = (static_cast<uint32_t>(data_[j]) << 24) |
                    (static_cast<uint32_t>(data_[j + 1]) << 16) |
                    (static_cast<uint32_t>(data_[j + 2]) << 8) |
                    static_cast<uint32_t>(data_[j + 3]);
    }
    for (uint32_t i = 16; i < 64; ++i) {
      schedule[i] = Gamma1(schedule[i - 2]) + schedule[i - 7] +
                    Gamma0(schedule[i - 15]) + schedule[i - 16];
    }

    uint32_t a = state_[0];
    uint32_t b = state_[1];
    uint32_t c = state_[2];
    uint32_t d = state_[3];
    uint32_t e = state_[4];
    uint32_t f = state_[5];
    uint32_t g = state_[6];
    uint32_t h = state_[7];

    for (uint32_t i = 0; i < 64; ++i) {
      const uint32_t t1 =
          h + Sigma1(e) + Choose(e, f, g) + kRoundConstants[i] + schedule[i];
      const uint32_t t2 = Sigma0(a) + Majority(a, b, c);
      h = g;
      g = f;
      f = e;
      e = d + t1;
      d = c;
      c = b;
      b = a;
      a = t1 + t2;
    }

    state_[0] += a;
    state_[1] += b;
    state_[2] += c;
    state_[3] += d;
    state_[4] += e;
    state_[5] += f;
    state_[6] += g;
    state_[7] += h;
  }

  std::array<uint8_t, kSha256BlockSize> data_{};
  uint32_t data_length_ = 0;
  uint64_t bit_length_ = 0;
  std::array<uint32_t, 8> state_{};
};

Digest Sha256Digest(const std::vector<uint8_t>& input) {
  Sha256 sha;
  if (!input.empty()) {
    sha.Update(input.data(), input.size());
  }
  return sha.Final();
}

}  // namespace

Digest HmacSha256(
    const uint8_t* data,
    size_t data_length,
    const uint8_t* key,
    size_t key_length) {
  std::vector<uint8_t> normalized_key(key, key + key_length);
  if (normalized_key.size() > kSha256BlockSize) {
    const Digest digest = Sha256Digest(normalized_key);
    normalized_key.assign(digest.begin(), digest.end());
  }
  normalized_key.resize(kSha256BlockSize, 0);

  std::vector<uint8_t> outer_pad(kSha256BlockSize);
  std::vector<uint8_t> inner_pad(kSha256BlockSize);
  for (size_t i = 0; i < kSha256BlockSize; ++i) {
    outer_pad[i] = normalized_key[i] ^ 0x5c;
    inner_pad[i] = normalized_key[i] ^ 0x36;
  }

  inner_pad.insert(inner_pad.end(), data, data + data_length);
  const Digest inner_hash = Sha256Digest(inner_pad);
  outer_pad.insert(outer_pad.end(), inner_hash.begin(), inner_hash.end());
  return Sha256Digest(outer_pad);
}

char* CopyHexDigest(const Digest& digest) {
  static constexpr std::array<char, 16> kHex = {
      '0', '1', '2', '3', '4', '5', '6', '7',
      '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  };

  char* output = static_cast<char*>(std::malloc(kDigestSize * 2 + 1));
  if (output == nullptr) {
    return nullptr;
  }

  for (size_t i = 0; i < digest.size(); ++i) {
    output[i * 2] = kHex[(digest[i] >> 4) & 0x0f];
    output[i * 2 + 1] = kHex[digest[i] & 0x0f];
  }
  output[kDigestSize * 2] = '\0';
  return output;
}

}  // namespace flutter_defender
