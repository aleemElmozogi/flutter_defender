#include <flutter_defender/defender_crypto.h>

#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

std::string ToHex(const flutter_defender::Digest& digest) {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string output;
  output.reserve(digest.size() * 2);
  for (const uint8_t byte : digest) {
    output.push_back(kHex[(byte >> 4) & 0x0f]);
    output.push_back(kHex[byte & 0x0f]);
  }
  return output;
}

bool ExpectHmac(
    const std::string& name,
    const std::vector<uint8_t>& key,
    const std::vector<uint8_t>& data,
    const std::string& expected) {
  const std::string actual = ToHex(flutter_defender::HmacSha256(
      data.data(), data.size(), key.data(), key.size()));
  if (actual == expected) {
    return true;
  }
  std::cerr << name << " failed: expected " << expected << ", got " << actual
            << '\n';
  return false;
}

std::vector<uint8_t> Bytes(const std::string& value) {
  return std::vector<uint8_t>(value.begin(), value.end());
}

}  // namespace

int main() {
  bool passed = true;
  passed &= ExpectHmac(
      "RFC 4231 case 1", std::vector<uint8_t>(20, 0x0b), Bytes("Hi There"),
      "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7");
  passed &= ExpectHmac(
      "RFC 4231 case 2", Bytes("Jefe"),
      Bytes("what do ya want for nothing?"),
      "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
  passed &= ExpectHmac(
      "RFC 4231 case 3", std::vector<uint8_t>(20, 0xaa),
      std::vector<uint8_t>(50, 0xdd),
      "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe");
  passed &= ExpectHmac(
      "RFC 4231 case 6", std::vector<uint8_t>(131, 0xaa),
      Bytes("Test Using Larger Than Block-Size Key - Hash Key First"),
      "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54");
  return passed ? 0 : 1;
}
