import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_defender/src/platform/pigeon/defender_messages.g.dart'
    as pigeon;
import 'package:flutter_defender/src/platform/pigeon_flutter_defender_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeFlutterDefenderPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDefenderPlatform {
  final List<(bool secureActive, bool overlayHardeningActive)> protectionCalls =
      <(bool, bool)>[];
  final List<pigeon.LifecycleSnapshot> savedSnapshots =
      <pigeon.LifecycleSnapshot>[];

  FlutterDefenderPlatformCallbacks? callbacks;
  pigeon.NativeRuntimeState runtimeState = pigeon.NativeRuntimeState(
    isForeground: true,
    isScreenCaptured: false,
    isEmulator: false,
    supportsOverlayHardening: true,
  );
  pigeon.LifecycleSnapshot lifecycleSnapshot = pigeon.LifecycleSnapshot(
    lastBackgroundedAtMs: null,
    wasAuthenticated: false,
    activeGuardKind: pigeon.DefenderGuardKind.none,
  );

  @override
  Future<void> clearLifecycleSnapshot() async {
    lifecycleSnapshot = pigeon.LifecycleSnapshot(
      lastBackgroundedAtMs: null,
      wasAuthenticated: false,
      activeGuardKind: pigeon.DefenderGuardKind.none,
    );
  }

  @override
  Future<pigeon.NativeRuntimeState> getRuntimeState() async => runtimeState;

  @override
  Future<pigeon.LifecycleSnapshot> loadLifecycleSnapshot() async =>
      lifecycleSnapshot;

  @override
  Future<void> saveLifecycleSnapshot(pigeon.LifecycleSnapshot snapshot) async {
    lifecycleSnapshot = snapshot;
    savedSnapshots.add(snapshot);
  }

  @override
  void setCallbacks(FlutterDefenderPlatformCallbacks? callbacks) {
    this.callbacks = callbacks;
  }

  @override
  Future<void> setProtectionState({
    required bool secureActive,
    required bool overlayHardeningActive,
  }) async {
    protectionCalls.add((secureActive, overlayHardeningActive));
  }

  void emitScreenshot() {
    callbacks?.onScreenshotDetected?.call();
  }

  void emitScreenCaptureChanged(bool active) {
    callbacks?.onScreenCaptureChanged?.call(active);
  }

  void emitForegroundStateChanged(bool active) {
    callbacks?.onForegroundStateChanged?.call(active);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterDefenderPlatform fakePlatform;
  late FlutterDefender defender;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 4, 12, 12);
    fakePlatform = FakeFlutterDefenderPlatform();
    FlutterDefenderPlatform.instance = fakePlatform;
    defender = FlutterDefender.instance;
    defender.debugSetNowProvider(() => now);
    await defender.init();
  });

  tearDown(() {
    defender.dispose();
    FlutterDefenderPlatform.instance = PigeonFlutterDefenderPlatform();
  });

  testWidgets(
    'init wires native callbacks and pause persists lifecycle state',
    (WidgetTester tester) async {
      expect(fakePlatform.callbacks, isNotNull);

      defender.setAuthenticated(true);
      defender.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(fakePlatform.savedSnapshots, isNotEmpty);
      expect(fakePlatform.savedSnapshots.last.wasAuthenticated, isTrue);
    },
  );

  testWidgets('blocking overlay prevents interaction for custom builders', (
    WidgetTester tester,
  ) async {
    var tapped = 0;

    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init(
      blockingScreenBuilder: (String message) => Center(child: Text(message)),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterDefenderLocalizations.localizationsDelegates,
        supportedLocales: FlutterDefenderLocalizations.supportedLocales,
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  tapped += 1;
                },
                child: const Text('tap me'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitScreenCaptureChanged(true);
    await tester.pumpAndSettle();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.screenCaptureBlocked,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('tap me'), findsNothing);
    expect(tapped, 0);
  });
}
