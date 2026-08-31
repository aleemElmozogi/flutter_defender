#ifndef FLUTTER_DEFENDER_ANDROID_EMULATOR_CLASSIFIER_H_
#define FLUTTER_DEFENDER_ANDROID_EMULATOR_CLASSIFIER_H_

#include <string>

namespace flutter_defender::platform_internal {

struct AndroidBuildIdentity {
  std::string fingerprint;
  std::string model;
  std::string manufacturer;
  std::string brand;
  std::string device;
  std::string product;
  std::string hardware;
};

bool IsAndroidEmulator(const AndroidBuildIdentity& identity);

}  // namespace flutter_defender::platform_internal

#endif  // FLUTTER_DEFENDER_ANDROID_EMULATOR_CLASSIFIER_H_
