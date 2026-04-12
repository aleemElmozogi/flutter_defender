import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_defender_platform_interface.dart';

/// An implementation of [FlutterDefenderPlatform] that uses method channels.
class MethodChannelFlutterDefender extends FlutterDefenderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_defender');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> setFlagSecure(bool enabled) async {
    await methodChannel.invokeMethod<void>('setFlagSecure', <String, bool>{
      'enabled': enabled,
    });
  }

  @override
  Future<bool> isOverlayPermissionDetected() async {
    return await methodChannel.invokeMethod<bool>(
          'isOverlayPermissionDetected',
        ) ??
        false;
  }

  @override
  Future<bool> isAppInForeground() async {
    return await methodChannel.invokeMethod<bool>('isAppInForeground') ?? true;
  }

  @override
  Future<bool> isEmulator() async {
    return await methodChannel.invokeMethod<bool>('isEmulator') ?? false;
  }

  @override
  Future<bool> isScreenCaptured() async {
    return await methodChannel.invokeMethod<bool>('isScreenCaptured') ?? false;
  }

  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    methodChannel.setMethodCallHandler(handler);
  }
}
