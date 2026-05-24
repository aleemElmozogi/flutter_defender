#include <flutter_defender/defender_platform.h>

#include "platform_detector_internal.h"

namespace flutter_defender {

bool IsDebuggerAttached() {
  return platform_internal::IsDebuggerAttachedImpl();
}

bool IsRootedOrJailbroken() {
  return platform_internal::IsRootedOrJailbrokenImpl();
}

bool IsEmulator() {
  return platform_internal::IsEmulatorImpl();
}

bool IsTampered() {
  return platform_internal::IsTamperedImpl();
}

}  // namespace flutter_defender
