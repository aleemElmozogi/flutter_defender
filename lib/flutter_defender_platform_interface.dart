import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_defender_method_channel.dart';

abstract class FlutterDefenderPlatform extends PlatformInterface {
  /// Constructs a FlutterDefenderPlatform.
  FlutterDefenderPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDefenderPlatform _instance = MethodChannelFlutterDefender();

  /// The default instance of [FlutterDefenderPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDefender].
  static FlutterDefenderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDefenderPlatform] when
  /// they register themselves.
  static set instance(FlutterDefenderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> setFlagSecure(bool enabled) {
    throw UnimplementedError('setFlagSecure() has not been implemented.');
  }

  Future<bool> isOverlayPermissionDetected() {
    throw UnimplementedError(
      'isOverlayPermissionDetected() has not been implemented.',
    );
  }

  Future<bool> isAppInForeground() {
    throw UnimplementedError('isAppInForeground() has not been implemented.');
  }

  Future<bool> isEmulator() {
    throw UnimplementedError('isEmulator() has not been implemented.');
  }

  Future<bool> isScreenCaptured() {
    throw UnimplementedError('isScreenCaptured() has not been implemented.');
  }

  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    throw UnimplementedError(
      'setMethodCallHandler() has not been implemented.',
    );
  }
}
