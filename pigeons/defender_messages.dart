import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/pigeon/defender_messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/aleem/flutter/defender/DefenderMessages.g.kt',
    kotlinOptions: KotlinOptions(package: 'aleem.flutter.defender'),
    swiftOut: 'ios/Classes/DefenderMessages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
enum DefenderGuardKind { none, sensitive, otp }

class NativeRuntimeState {
  bool? isForeground;
  bool? isScreenCaptured;
  bool? isEmulator;
  bool? supportsOverlayHardening;
}

class LifecycleSnapshot {
  int? lastBackgroundedAtMs;
  bool? wasAuthenticated;
  DefenderGuardKind? activeGuardKind;
}

class AdvancedSecuritySignals {
  bool? rootedOrJailbroken;
  bool? proxyEnabled;
  bool? vpnEnabled;
  bool? debuggerAttached;
  bool? tamperingDetected;
  String? tamperingDetails;
}

@HostApi()
abstract class DefenderHostApi {
  void setProtectionState(bool secureActive, bool overlayHardeningActive);

  NativeRuntimeState getRuntimeState();

  AdvancedSecuritySignals getAdvancedSecuritySignals();

  void secureWrite(String key, String value);

  String? secureRead(String key);

  void secureDelete(String key);

  void secureClearAll();

  void saveLifecycleSnapshot(LifecycleSnapshot snapshot);

  LifecycleSnapshot loadLifecycleSnapshot();

  void clearLifecycleSnapshot();
}

@FlutterApi()
abstract class DefenderFlutterApi {
  void onScreenshotDetected();

  void onScreenCaptureChanged(bool active);

  void onOverlayViolation();

  void onForegroundStateChanged(bool active);
}
