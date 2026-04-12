import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:flutter_defender/flutter_defender_method_channel.dart';
import 'package:flutter_defender/flutter_defender_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeFlutterDefenderPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDefenderPlatform {
  final List<bool> flagSecureCalls = <bool>[];

  bool overlayDetected = false;
  bool appInForeground = true;
  bool emulator = false;
  bool screenCaptured = false;

  Future<dynamic> Function(MethodCall call)? _handler;

  @override
  Future<String?> getPlatformVersion() => Future<String?>.value('test');

  @override
  Future<bool> isAppInForeground() => Future<bool>.value(appInForeground);

  @override
  Future<bool> isEmulator() => Future<bool>.value(emulator);

  @override
  Future<bool> isOverlayPermissionDetected() =>
      Future<bool>.value(overlayDetected);

  @override
  Future<bool> isScreenCaptured() => Future<bool>.value(screenCaptured);

  @override
  Future<void> setFlagSecure(bool enabled) async {
    flagSecureCalls.add(enabled);
  }

  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    _handler = handler;
  }

  Future<void> emit(String method, [Object? arguments]) async {
    await _handler?.call(MethodCall(method, arguments));
  }
}

class TestNavigatorApp extends StatelessWidget {
  const TestNavigatorApp({
    super.key,
    required this.navigatorKey,
    required this.observer,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final FlutterDefenderNavigatorObserver observer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: FlutterDefenderLocalizations.localizationsDelegates,
      supportedLocales: FlutterDefenderLocalizations.supportedLocales,
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: '/public',
      routes: <String, WidgetBuilder>{
        '/public': (_) => const Scaffold(body: Center(child: Text('public'))),
        '/sensitive': (_) =>
            const Scaffold(body: Center(child: Text('sensitive'))),
        '/otp': (_) => const Scaffold(body: Center(child: Text('otp'))),
        '/auth': (_) => const Scaffold(body: Center(child: Text('auth'))),
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterDefenderPlatform fakePlatform;
  late FlutterDefender defender;

  setUp(() {
    fakePlatform = FakeFlutterDefenderPlatform();
    FlutterDefenderPlatform.instance = fakePlatform;
    defender = FlutterDefender.instance;
  });

  tearDown(() {
    defender.dispose();
    FlutterDefenderPlatform.instance = MethodChannelFlutterDefender();
  });

  Future<GlobalKey<NavigatorState>> pumpApp(WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TestNavigatorApp(
        navigatorKey: navigatorKey,
        observer: defender.navigatorObserver,
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  Future<void> initializeDefender({
    List<String> sensitiveRoutes = const <String>['/sensitive', '/otp'],
    List<String> authenticatedRoutes = const <String>['/auth'],
    int otpBackgroundTimeoutSeconds = 60,
    int pinBackgroundTimeoutSeconds = 120,
    bool enableOverlayDetection = false,
    bool enableForegroundCheck = true,
    VoidCallback? onLogoutRequested,
  }) {
    return defender.init(
      sensitiveRoutes: sensitiveRoutes,
      otpRouteName: '/otp',
      authenticatedRoutes: authenticatedRoutes,
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      pinBackgroundTimeoutSeconds: pinBackgroundTimeoutSeconds,
      enableOverlayDetection: enableOverlayDetection,
      enableForegroundCheck: enableForegroundCheck,
      onLogoutRequested: onLogoutRequested,
    );
  }

  testWidgets(
    'toggles secure flag when entering and leaving sensitive routes',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

      await initializeDefender();
      await tester.pump();

      expect(fakePlatform.flagSecureCalls.last, isFalse);

      navigatorKey.currentState!.pushNamed('/sensitive');
      await tester.pumpAndSettle();

      expect(fakePlatform.flagSecureCalls.last, isTrue);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(fakePlatform.flagSecureCalls.last, isFalse);
    },
  );

  testWidgets('shows a temporary blocking overlay for screenshot attempts', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

    await initializeDefender();
    navigatorKey.currentState!.pushNamed('/sensitive');
    await tester.pumpAndSettle();

    await fakePlatform.emit('onScreenshotAttempted');
    await tester.pump();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.screenshotsBlocked),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.screenshotsBlocked),
      ),
      findsNothing,
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('blocks and clears when native screen capture state changes', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

    await initializeDefender();
    navigatorKey.currentState!.pushNamed('/sensitive');
    await tester.pumpAndSettle();

    fakePlatform.screenCaptured = true;
    await fakePlatform.emit('onScreenCaptureChanged', <String, bool>{
      'active': true,
    });
    await tester.pump();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.screenCaptureBlocked),
      ),
      findsOneWidget,
    );

    fakePlatform.screenCaptured = false;
    await fakePlatform.emit('onScreenCaptureChanged', <String, bool>{
      'active': false,
    });
    await tester.pump();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.screenCaptureBlocked),
      ),
      findsNothing,
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('blocks sensitive routes when overlay detection trips', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

    fakePlatform.overlayDetected = true;
    await initializeDefender(enableOverlayDetection: true);
    navigatorKey.currentState!.pushNamed('/sensitive');
    await tester.pumpAndSettle();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.overlaysBlocked),
      ),
      findsOneWidget,
    );

    fakePlatform.overlayDetected = false;
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('blocks sensitive routes when foreground verification fails', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

    fakePlatform.appInForeground = false;
    await initializeDefender(enableOverlayDetection: false);
    navigatorKey.currentState!.pushNamed('/sensitive');
    await tester.pumpAndSettle();

    expect(
      find.text(
        FlutterDefenderMessages.stringFor(FlutterDefenderMessageId.foregroundRequired),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pops the otp route after background timeout on resume', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);

    await initializeDefender(otpBackgroundTimeoutSeconds: -1);
    navigatorKey.currentState!.pushNamed('/otp');
    await tester.pumpAndSettle();

    expect(find.text('otp'), findsOneWidget);

    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('public'), findsOneWidget);
    expect(find.text('otp'), findsNothing);
  });

  testWidgets('requests logout after authenticated-route background timeout', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);
    var logoutRequested = false;

    await initializeDefender(
      pinBackgroundTimeoutSeconds: -1,
      onLogoutRequested: () {
        logoutRequested = true;
      },
    );
    navigatorKey.currentState!.pushNamed('/auth');
    await tester.pumpAndSettle();

    defender.didChangeAppLifecycleState(AppLifecycleState.paused);
    defender.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(logoutRequested, isTrue);
  });
}
