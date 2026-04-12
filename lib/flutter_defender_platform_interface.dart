import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/platform/pigeon/defender_messages.g.dart';
import 'src/platform/pigeon_flutter_defender_platform.dart';

typedef FlutterDefenderBoolCallback = void Function(bool value);

class FlutterDefenderPlatformCallbacks {
  const FlutterDefenderPlatformCallbacks({
    this.onScreenshotDetected,
    this.onScreenCaptureChanged,
    this.onOverlayViolation,
    this.onForegroundStateChanged,
  });

  final VoidCallback? onScreenshotDetected;
  final FlutterDefenderBoolCallback? onScreenCaptureChanged;
  final VoidCallback? onOverlayViolation;
  final FlutterDefenderBoolCallback? onForegroundStateChanged;
}

abstract class FlutterDefenderPlatform extends PlatformInterface {
  FlutterDefenderPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDefenderPlatform _instance = PigeonFlutterDefenderPlatform();

  static FlutterDefenderPlatform get instance => _instance;

  static set instance(FlutterDefenderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> setProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) {
    throw UnimplementedError('setProtectionState() has not been implemented.');
  }

  Future<NativeRuntimeState> getRuntimeState() {
    throw UnimplementedError('getRuntimeState() has not been implemented.');
  }

  Future<void> saveLifecycleSnapshot(LifecycleSnapshot snapshot) {
    throw UnimplementedError(
      'saveLifecycleSnapshot() has not been implemented.',
    );
  }

  Future<LifecycleSnapshot> loadLifecycleSnapshot() {
    throw UnimplementedError(
      'loadLifecycleSnapshot() has not been implemented.',
    );
  }

  Future<void> clearLifecycleSnapshot() {
    throw UnimplementedError(
      'clearLifecycleSnapshot() has not been implemented.',
    );
  }

  void setCallbacks(FlutterDefenderPlatformCallbacks? callbacks) {
    throw UnimplementedError('setCallbacks() has not been implemented.');
  }
}
