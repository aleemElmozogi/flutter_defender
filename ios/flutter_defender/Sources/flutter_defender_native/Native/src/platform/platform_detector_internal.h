#ifndef FLUTTER_DEFENDER_PLATFORM_DETECTOR_INTERNAL_H_
#define FLUTTER_DEFENDER_PLATFORM_DETECTOR_INTERNAL_H_

namespace flutter_defender::platform_internal {

bool IsDebuggerAttachedImpl();
bool IsRootedOrJailbrokenImpl();
bool IsEmulatorImpl();
bool IsTamperedImpl();

}  // namespace flutter_defender::platform_internal

#endif  // FLUTTER_DEFENDER_PLATFORM_DETECTOR_INTERNAL_H_
