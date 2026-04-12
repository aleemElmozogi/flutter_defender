import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SessionController sessionController = SessionController();

  await FlutterDefender.instance.init(
    otpBackgroundTimeoutSeconds: 10,
    pinBackgroundTimeoutSeconds: 20,
    onLogoutRequested: () {
      sessionController.handleTimeoutLogout();
      _navigatorKey.currentState?.popUntil((Route<dynamic> route) => route.isFirst);
    },
    blockingScreenBuilder: (String message) {
      return ColoredBox(
        color: const Color(0xFF08111C),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF122235),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2F4E73)),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    },
  );

  runApp(MyApp(sessionController: sessionController));
}

class SessionController extends ChangeNotifier {
  bool authenticated = false;
  String lastEvent = 'Ready';

  void toggleAuth() {
    authenticated = !authenticated;
    FlutterDefender.instance.setAuthenticated(authenticated);
    lastEvent = authenticated ? 'Authenticated session enabled' : 'Session cleared';
    notifyListeners();
  }

  void handleTimeoutLogout() {
    authenticated = false;
    FlutterDefender.instance.setAuthenticated(false);
    lastEvent = 'Logout requested after background timeout';
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (BuildContext context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...FlutterDefenderLocalizations.localizationsDelegates,
          ],
          supportedLocales: mergeFlutterDefenderSupportedLocales(
            const <Locale>[Locale('en')],
          ),
          routes: <String, WidgetBuilder>{
            '/': (_) => HomeScreen(sessionController: sessionController),
            '/sensitive': (_) => const FlutterDefenderSensitiveGuard(
              child: DemoScreen(
                title: 'Sensitive Screen',
                body:
                    'Open Android recents, try a screenshot, or start recording/mirroring on iOS to validate the guard.',
              ),
            ),
            '/otp': (_) => const FlutterDefenderOtpGuard(
              child: DemoScreen(
                title: 'OTP Screen',
                body:
                    'Background the app for more than 10 seconds. Returning should pop only this route.',
              ),
            ),
          },
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final bool authenticated = sessionController.authenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_defender example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            authenticated ? 'Session active' : 'Session inactive',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(sessionController.lastEvent),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: sessionController.toggleAuth,
            child: Text(authenticated ? 'Sign out' : 'Sign in'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/sensitive');
            },
            child: const Text('Open sensitive screen'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/otp');
            },
            child: const Text('Open OTP screen'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Manual checks',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Open the sensitive screen and verify Android recents are blanked.\n'
            '2. Start screen recording or mirroring on iOS and verify the blocking screen appears.\n'
            '3. Use the OTP screen and background the app for more than 10 seconds.\n'
            '4. Sign in, background the app for more than 20 seconds, and verify logout occurs.\n'
            '5. Build a release on an emulator/simulator and verify guarded screens are blocked.',
          ),
        ],
      ),
    );
  }
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            body,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
