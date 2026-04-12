import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final FlutterDefender defender = FlutterDefender.instance;
  final FlutterDefenderPlatform platform = FlutterDefenderPlatform.instance;

  group('flutter_defender integration', () {
    testWidgets('returns a platform version string', (
      WidgetTester tester,
    ) async {
      final String? version = await defender.getPlatformVersion();

      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    testWidgets('exposes native guardrail queries as booleans', (
      WidgetTester tester,
    ) async {
      expect(await platform.isAppInForeground(), isA<bool>());
      expect(await platform.isOverlayPermissionDetected(), isA<bool>());
      expect(await platform.isEmulator(), isA<bool>());
      expect(await platform.isScreenCaptured(), isA<bool>());
    });

    testWidgets('setFlagSecure can be toggled without throwing', (
      WidgetTester tester,
    ) async {
      await expectLater(platform.setFlagSecure(true), completes);
      await expectLater(platform.setFlagSecure(false), completes);
    });

    testWidgets('native callbacks can be registered and cleared', (
      WidgetTester tester,
    ) async {
      Future<dynamic> noopHandler(MethodCall call) async => null;

      expect(() => platform.setMethodCallHandler(noopHandler), returnsNormally);
      expect(() => platform.setMethodCallHandler(null), returnsNormally);
    });
  });
}
