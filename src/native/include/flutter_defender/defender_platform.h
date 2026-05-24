#ifndef FLUTTER_DEFENDER_PLATFORM_H_
#define FLUTTER_DEFENDER_PLATFORM_H_

namespace flutter_defender {

bool IsDebuggerAttached();
bool IsRootedOrJailbroken();
bool IsEmulator();
bool IsTampered();

}  // namespace flutter_defender

#endif  // FLUTTER_DEFENDER_PLATFORM_H_
