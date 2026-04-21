import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_defender/src/platform/pigeon/defender_messages.g.dart'
    as pigeon;
import 'package:flutter_defender/src/platform/pigeon_flutter_defender_platform.dart';
import 'package:flutter/services.dart';
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
  pigeon.AdvancedSecuritySignals advancedSecuritySignals =
      pigeon.AdvancedSecuritySignals(
        rootedOrJailbroken: false,
        proxyEnabled: false,
        vpnEnabled: false,
        debuggerAttached: false,
        tamperingDetected: false,
        tamperingDetails: null,
      );
  final Map<String, String> secureStorage = <String, String>{};
  bool throwOnGetRuntimeState = false;
  bool throwOnSecureWrite = false;
  bool throwOnSecureRead = false;
  bool throwOnSecureDelete = false;
  bool throwOnSecureClearAll = false;
  Duration loadLifecycleSnapshotDelay = Duration.zero;
  int secureClearAllCallCount = 0;

  @override
  Future<void> clearLifecycleSnapshot() async {
    lifecycleSnapshot = pigeon.LifecycleSnapshot(
      lastBackgroundedAtMs: null,
      wasAuthenticated: false,
      activeGuardKind: pigeon.DefenderGuardKind.none,
    );
  }

  @override
  Future<pigeon.NativeRuntimeState> getRuntimeState() async {
    if (throwOnGetRuntimeState) {
      throw PlatformException(code: 'runtime_state_failure');
    }
    return runtimeState;
  }

  @override
  Future<pigeon.AdvancedSecuritySignals> getAdvancedSecuritySignals() async =>
      advancedSecuritySignals;

  @override
  Future<pigeon.LifecycleSnapshot> loadLifecycleSnapshot() async {
    if (loadLifecycleSnapshotDelay == Duration.zero) {
      return lifecycleSnapshot;
    }
    return Future<pigeon.LifecycleSnapshot>.delayed(
      loadLifecycleSnapshotDelay,
      () => lifecycleSnapshot,
    );
  }

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

  @override
  Future<void> secureWrite({required String key, required String value}) async {
    if (throwOnSecureWrite) {
      throw PlatformException(code: 'secure_write_failure');
    }
    secureStorage[key] = value;
  }

  @override
  Future<String?> secureRead(String key) async {
    if (throwOnSecureRead) {
      throw PlatformException(code: 'secure_read_failure');
    }
    return secureStorage[key];
  }

  @override
  Future<void> secureDelete(String key) async {
    if (throwOnSecureDelete) {
      throw PlatformException(code: 'secure_delete_failure');
    }
    secureStorage.remove(key);
  }

  @override
  Future<void> secureClearAll() async {
    secureClearAllCallCount += 1;
    if (throwOnSecureClearAll) {
      throw PlatformException(code: 'secure_clear_failure');
    }
    secureStorage.clear();
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
    expect(find.text('tap me'), findsOneWidget);
    expect(tapped, 0);
  });

  testWidgets(
    'iOS inactive lifecycle conceals guarded content immediately',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterDefenderSensitiveGuard(
            child: const Scaffold(body: Text('secret')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(defender.shouldConcealGuardedContent, isFalse);

      defender.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isTrue);

      defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('secure storage helper is fail-fast on platform errors', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init(enableSecureStorageHelper: true);

    fakePlatform.throwOnSecureWrite = true;
    await expectLater(
      defender.secureWrite(key: 'token', value: '123'),
      throwsA(isA<PlatformException>()),
    );

    fakePlatform.throwOnSecureRead = true;
    await expectLater(
      defender.secureRead('token'),
      throwsA(isA<PlatformException>()),
    );

    fakePlatform.throwOnSecureDelete = true;
    await expectLater(
      defender.secureDelete('token'),
      throwsA(isA<PlatformException>()),
    );

    fakePlatform.throwOnSecureClearAll = true;
    await expectLater(
      defender.secureClearAll(),
      throwsA(isA<PlatformException>()),
    );
  });

  testWidgets(
    'cold-start authenticated timeout clears secure storage before logout',
    (WidgetTester tester) async {
      defender.dispose();
      defender = FlutterDefender.instance;
      final DateTime base = DateTime(2026, 4, 12, 12);
      defender.debugSetNowProvider(() => base);
      final int oldTimestamp = base
          .subtract(const Duration(seconds: 200))
          .millisecondsSinceEpoch;
      fakePlatform.lifecycleSnapshot = pigeon.LifecycleSnapshot(
        lastBackgroundedAtMs: oldTimestamp,
        wasAuthenticated: true,
        activeGuardKind: pigeon.DefenderGuardKind.none,
      );
      var logoutCalls = 0;
      await defender.init(
        authenticatedBackgroundTimeoutSeconds: 20,
        enableSecureStorageHelper: true,
        clearSecureStorageOnLogout: true,
        onLogoutRequested: () {
          logoutCalls += 1;
        },
      );

      expect(fakePlatform.secureClearAllCallCount, 1);
      expect(logoutCalls, 1);
    },
  );

  testWidgets('latest init call wins under concurrent calls', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    fakePlatform.loadLifecycleSnapshotDelay = const Duration(milliseconds: 100);

    final Future<void> initA = defender.init(enableForegroundCheck: true);
    final Future<void> initB = defender.init(enableForegroundCheck: false);
    await Future.wait(<Future<void>>[initA, initB]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterDefenderLocalizations.localizationsDelegates,
        supportedLocales: FlutterDefenderLocalizations.supportedLocales,
        home: const FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitForegroundStateChanged(false);
    await tester.pumpAndSettle();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.foregroundRequired,
        ),
      ),
      findsNothing,
    );
  });
}
