import 'dart:async';

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
  bool throwOnSetProtectionState = false;
  bool throwOnSecureWrite = false;
  bool throwOnSecureRead = false;
  bool throwOnSecureDelete = false;
  bool throwOnSecureClearAll = false;
  Completer<pigeon.NativeRuntimeState>? getRuntimeStateCompleter;
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
    final Completer<pigeon.NativeRuntimeState>? completer =
        getRuntimeStateCompleter;
    if (completer != null) {
      return completer.future;
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
    if (throwOnSetProtectionState) {
      throw PlatformException(code: 'protection_state_failure');
    }
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

  void emitOverlayViolation() {
    callbacks?.onOverlayViolation?.call();
  }

  void emitOverlayCleared() {
    callbacks?.onOverlayCleared?.call();
  }

  void emitForegroundStateChanged(bool active) {
    callbacks?.onForegroundStateChanged?.call(active);
  }

  void emitWindowFocusChanged(bool hasFocus) {
    callbacks?.onWindowFocusChanged?.call(hasFocus);
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
      expect(fakePlatform.protectionCalls, isEmpty);

      defender.setAuthenticated(true);
      defender.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(fakePlatform.savedSnapshots, isNotEmpty);
      expect(fakePlatform.savedSnapshots.last.wasAuthenticated, isTrue);
    },
  );

  testWidgets('platform failures remain fail-open by default', (
    WidgetTester tester,
  ) async {
    fakePlatform.throwOnSetProtectionState = true;

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isFalse);
    expect(find.text('secure'), findsOneWidget);
  });

  testWidgets('strict platform failure policy blocks guarded content', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init(failClosedOnPlatformError: true);
    fakePlatform.throwOnSetProtectionState = true;

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isTrue);
    expect(
      find.text(FlutterDefenderMessages.protectionUnavailable),
      findsOneWidget,
    );

    fakePlatform.throwOnSetProtectionState = false;
    fakePlatform.emitForegroundStateChanged(true);
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isFalse);
    expect(find.text('secure'), findsOneWidget);
  });

  testWidgets(
    'window focus loss conceals guarded content without blocking or timeout',
    (WidgetTester tester) async {
      defender.dispose();
      defender = FlutterDefender.instance;
      final DateTime base = DateTime(2026, 4, 12, 12);
      defender.debugSetNowProvider(() => base);
      var logoutCalls = 0;
      await defender.init(
        authenticatedBackgroundTimeoutSeconds: 1,
        onLogoutRequested: () {
          logoutCalls += 1;
        },
      );
      defender.setAuthenticated(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: FlutterDefenderSensitiveGuard(
            child: Scaffold(body: Text('secure')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      fakePlatform.emitWindowFocusChanged(false);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isTrue);
      expect(defender.hasBlockingOverlay, isFalse);
      expect(
        find.text(FlutterDefenderMessages.protectedContentHidden),
        findsOneWidget,
      );
      expect(
        find.text(FlutterDefenderMessages.foregroundRequired),
        findsNothing,
      );

      defender.debugSetNowProvider(() => base.add(const Duration(seconds: 30)));
      fakePlatform.emitWindowFocusChanged(true);
      await tester.pumpAndSettle();

      expect(logoutCalls, 0);
      expect(defender.shouldConcealGuardedContent, isFalse);
      expect(
        find.text(FlutterDefenderMessages.protectedContentHidden),
        findsNothing,
      );
    },
  );

  testWidgets(
    'android inactive system prompt does not trigger blocking or timeout',
    (WidgetTester tester) async {
      defender.dispose();
      defender = FlutterDefender.instance;
      final DateTime base = DateTime(2026, 4, 12, 12);
      defender.debugSetNowProvider(() => base);
      var logoutCalls = 0;
      await defender.init(
        authenticatedBackgroundTimeoutSeconds: 1,
        onLogoutRequested: () {
          logoutCalls += 1;
        },
      );
      defender.setAuthenticated(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: FlutterDefenderSensitiveGuard(
            child: Scaffold(body: Text('secure')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      defender.didChangeAppLifecycleState(AppLifecycleState.inactive);
      defender.debugSetNowProvider(() => base.add(const Duration(seconds: 30)));
      await tester.pump();

      expect(find.text('secure'), findsOneWidget);
      expect(defender.hasBlockingOverlay, isFalse);

      defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(logoutCalls, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('overlay violation keeps the overlay-specific message', (
    WidgetTester tester,
  ) async {
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
        home: const FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitOverlayViolation();
    fakePlatform.emitForegroundStateChanged(false);
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isTrue);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.overlaysBlocked,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.foregroundRequired,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('overlay violation recovers without unregistering the guard', (
    WidgetTester tester,
  ) async {
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
        home: const FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitOverlayViolation();
    await tester.pump();

    expect(defender.hasBlockingOverlay, isTrue);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.overlaysBlocked,
        ),
      ),
      findsOneWidget,
    );

    fakePlatform.emitOverlayCleared();
    await tester.pump();

    expect(defender.hasBlockingOverlay, isFalse);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.overlaysBlocked,
        ),
      ),
      findsNothing,
    );
    expect(find.text('secure'), findsOneWidget);
  });

  testWidgets('default blocking overlay scrolls in constrained guards', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init();

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(
            body: ColoredBox(
              color: Colors.white,
              child: Center(child: Text('secure')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitOverlayViolation();
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isTrue);
    expect(tester.takeException(), isNull);
    final Finder scrollableFinder = find.descendant(
      of: find.byType(BlockingScreen),
      matching: find.byType(Scrollable),
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(scrollableFinder)
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    final Finder hitTestableScrollable = scrollableFinder.hitTestable();
    expect(hitTestableScrollable, findsOneWidget);

    await tester.drag(hitTestableScrollable, const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
  });

  testWidgets('foreground message appears for an actual background signal', (
    WidgetTester tester,
  ) async {
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
        home: const FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitForegroundStateChanged(false);
    await tester.pumpAndSettle();

    expect(defender.hasBlockingOverlay, isTrue);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.foregroundRequired,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.overlaysBlocked,
        ),
      ),
      findsNothing,
    );
  });

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

    await tester.tap(find.text('tap me'), warnIfMissed: false);
    await tester.pump();

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
      expect(
        find.text(FlutterDefenderMessages.protectedContentHidden),
        findsOneWidget,
      );

      defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'resume clears inactive shield while native refresh is pending',
    (WidgetTester tester) async {
      expect(defender.shouldConcealGuardedContent, isFalse);

      defender.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isTrue);

      fakePlatform.getRuntimeStateCompleter =
          Completer<pigeon.NativeRuntimeState>();
      defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(defender.shouldConcealGuardedContent, isFalse);

      fakePlatform.getRuntimeStateCompleter!.complete(
        fakePlatform.runtimeState,
      );
      fakePlatform.getRuntimeStateCompleter = null;
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('secure content guard conceals only its own subtree', (
    WidgetTester tester,
  ) async {
    var outsideTaps = 0;
    var insideTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  outsideTaps += 1;
                },
                child: const Text('outside action'),
              ),
              SizedBox(
                width: 280,
                height: 180,
                child: FlutterDefenderSecureContentGuard(
                  child: ElevatedButton(
                    onPressed: () {
                      insideTaps += 1;
                    },
                    child: const Text('inside secret'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    fakePlatform.emitScreenCaptureChanged(true);
    await tester.pump();

    expect(
      find.text(FlutterDefenderMessages.protectedContentHidden),
      findsOneWidget,
    );
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.screenCaptureBlocked,
        ),
      ),
      findsNothing,
    );

    await tester.tap(find.text('outside action'));
    await tester.tap(find.text('inside secret'), warnIfMissed: false);
    await tester.pump();

    expect(outsideTaps, 1);
    expect(insideTaps, 0);
  });

  testWidgets('proxy vpn and rasp signals do not block by default', (
    WidgetTester tester,
  ) async {
    fakePlatform.advancedSecuritySignals = pigeon.AdvancedSecuritySignals(
      rootedOrJailbroken: false,
      proxyEnabled: true,
      vpnEnabled: true,
      debuggerAttached: true,
      tamperingDetected: true,
      tamperingDetails: 'debugger,hooking',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(defender.shouldConcealGuardedContent, isFalse);
    expect(find.text('secure'), findsOneWidget);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.proxyOrVpnBlocked,
        ),
      ),
      findsNothing,
    );
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.tamperingBlocked,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('explicit proxy vpn detection blocks guarded content', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init(enableProxyVpnDetection: true);
    fakePlatform.advancedSecuritySignals = pigeon.AdvancedSecuritySignals(
      rootedOrJailbroken: false,
      proxyEnabled: false,
      vpnEnabled: true,
      debuggerAttached: false,
      tamperingDetected: false,
      tamperingDetails: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(defender.shouldConcealGuardedContent, isTrue);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.proxyOrVpnBlocked,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('explicit rasp detection blocks debugger tampering signals', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    await defender.init(enableRaspDetection: true);
    fakePlatform.advancedSecuritySignals = pigeon.AdvancedSecuritySignals(
      rootedOrJailbroken: false,
      proxyEnabled: false,
      vpnEnabled: false,
      debuggerAttached: true,
      tamperingDetected: false,
      tamperingDetails: 'debugger',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterDefenderSensitiveGuard(
          child: Scaffold(body: Text('secure')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(defender.shouldConcealGuardedContent, isTrue);
    expect(
      find.text(
        FlutterDefenderMessages.stringFor(
          FlutterDefenderMessageId.tamperingBlocked,
        ),
      ),
      findsOneWidget,
    );
  });

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

  testWidgets('authenticated timeout fires at configured boundary', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    final DateTime base = DateTime(2026, 4, 12, 12);
    defender.debugSetNowProvider(() => base);
    var logoutCalls = 0;
    await defender.init(
      authenticatedBackgroundTimeoutSeconds: 20,
      onLogoutRequested: () {
        logoutCalls += 1;
      },
    );

    defender.setAuthenticated(true);
    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 20)));
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(logoutCalls, 1);
  });

  testWidgets('android resume sequence preserves original background time', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    final DateTime base = DateTime(2026, 4, 12, 12);
    defender.debugSetNowProvider(() => base);
    var logoutCalls = 0;
    await defender.init(
      authenticatedBackgroundTimeoutSeconds: 20,
      onLogoutRequested: () {
        logoutCalls += 1;
      },
    );

    defender.setAuthenticated(true);
    defender.didChangeAppLifecycleState(AppLifecycleState.inactive);
    defender.didChangeAppLifecycleState(AppLifecycleState.hidden);
    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 20)));
    defender.didChangeAppLifecycleState(AppLifecycleState.hidden);
    defender.didChangeAppLifecycleState(AppLifecycleState.inactive);
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(logoutCalls, 1);
  });

  testWidgets('native foreground callback applies authenticated timeout', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    final DateTime base = DateTime(2026, 4, 12, 12);
    defender.debugSetNowProvider(() => base);
    var logoutCalls = 0;
    await defender.init(
      authenticatedBackgroundTimeoutSeconds: 20,
      onLogoutRequested: () {
        logoutCalls += 1;
      },
    );

    defender.setAuthenticated(true);
    fakePlatform.emitForegroundStateChanged(false);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 20)));
    fakePlatform.emitForegroundStateChanged(true);
    await tester.pump();

    expect(logoutCalls, 1);
  });

  testWidgets('current authenticated timeout overrides deprecated alias', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    final DateTime base = DateTime(2026, 4, 12, 12);
    defender.debugSetNowProvider(() => base);
    var logoutCalls = 0;
    await defender.init(
      authenticatedBackgroundTimeoutSeconds: 20,
      // ignore: deprecated_member_use_from_same_package
      pinBackgroundTimeoutSeconds: 10,
      onLogoutRequested: () {
        logoutCalls += 1;
      },
    );

    defender.setAuthenticated(true);
    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 10)));
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(logoutCalls, 0);

    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 30)));
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(logoutCalls, 1);
  });

  testWidgets('otp timeout pops guard at configured boundary', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;
    final DateTime base = DateTime(2026, 4, 12, 12);
    defender.debugSetNowProvider(() => base);
    await defender.init(otpBackgroundTimeoutSeconds: 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FlutterDefenderOtpGuard(
                        child: Scaffold(body: Text('otp')),
                      ),
                    ),
                  );
                },
                child: const Text('open otp'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open otp'));
    await tester.pumpAndSettle();
    expect(find.text('otp'), findsOneWidget);

    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.debugSetNowProvider(() => base.add(const Duration(seconds: 10)));
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('otp'), findsNothing);
  });

  testWidgets('latest init call wins under concurrent calls', (
    WidgetTester tester,
  ) async {
    defender.dispose();
    defender = FlutterDefender.instance;

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    fakePlatform.emitForegroundStateChanged(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

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
