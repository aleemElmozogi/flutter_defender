import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/src/platform/pigeon/defender_messages.g.dart'
    as pigeon;
import 'package:flutter_defender/src/platform/pigeon_flutter_defender_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:flutter_defender_example/main.dart';

class _FakeFlutterDefenderPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDefenderPlatform {
  @override
  Future<void> clearLifecycleSnapshot() async {}

  @override
  Future<pigeon.AdvancedSecuritySignals> getAdvancedSecuritySignals() async =>
      pigeon.AdvancedSecuritySignals(
        rootedOrJailbroken: false,
        proxyEnabled: false,
        vpnEnabled: false,
        debuggerAttached: false,
        tamperingDetected: false,
        tamperingDetails: null,
      );

  @override
  Future<pigeon.NativeRuntimeState> getRuntimeState() async =>
      pigeon.NativeRuntimeState(
        isForeground: true,
        isScreenCaptured: false,
        isEmulator: false,
        supportsOverlayHardening: true,
      );

  @override
  Future<pigeon.LifecycleSnapshot> loadLifecycleSnapshot() async =>
      pigeon.LifecycleSnapshot(
        lastBackgroundedAtMs: null,
        wasAuthenticated: false,
        activeGuardKind: pigeon.DefenderGuardKind.none,
      );

  @override
  Future<void> saveLifecycleSnapshot(pigeon.LifecycleSnapshot snapshot) async {}

  @override
  Future<void> secureClearAll() async {}

  @override
  Future<void> secureDelete(String key) async {}

  @override
  Future<String?> secureRead(String key) async => null;

  @override
  Future<void> secureWrite({
    required String key,
    required String value,
  }) async {}

  @override
  Future<void> setProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) async {}

  @override
  void setCallbacks(FlutterDefenderPlatformCallbacks? callbacks) {}
}

void main() {
  tearDown(() {
    FlutterDefender.instance.dispose();
    FlutterDefenderPlatform.instance = PigeonFlutterDefenderPlatform();
  });

  testWidgets('example home renders guarded actions', (
    WidgetTester tester,
  ) async {
    FlutterDefenderPlatform.instance = _FakeFlutterDefenderPlatform();
    final SessionController sessionController = SessionController();
    sessionController.registerLogoutHandler(() {
      sessionController.handleTimeoutLogout();
    });
    await sessionController.applyProfile(sessionController.activeProfile);

    await tester.pumpWidget(MyApp(sessionController: sessionController));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Feature Lab'), findsOneWidget);
    expect(find.text('Configuration Profiles'), findsOneWidget);
    expect(find.text('Session'), findsWidgets);
  });
}
