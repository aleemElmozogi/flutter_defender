import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_defender/flutter_defender_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterDefenderPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDefenderPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> isAppInForeground() => Future.value(true);

  @override
  Future<bool> isEmulator() => Future.value(false);

  @override
  Future<bool> isOverlayPermissionDetected() => Future.value(false);

  @override
  Future<bool> isScreenCaptured() => Future.value(false);

  @override
  Future<void> setFlagSecure(bool enabled) async {}

  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {}
}

void main() {
  final FlutterDefenderPlatform initialPlatform =
      FlutterDefenderPlatform.instance;

  test('$MethodChannelFlutterDefender is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterDefender>());
  });

  test('getPlatformVersion', () async {
    FlutterDefender flutterDefenderPlugin = FlutterDefender();
    MockFlutterDefenderPlatform fakePlatform = MockFlutterDefenderPlatform();
    FlutterDefenderPlatform.instance = fakePlatform;

    expect(await flutterDefenderPlugin.getPlatformVersion(), '42');
  });
}
