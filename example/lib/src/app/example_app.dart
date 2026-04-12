import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/security/presentation/demo_screens.dart';
import 'session/session_controller.dart';

class MyApp extends StatelessWidget {
  const MyApp({required this.sessionController, this.navigatorKey, super.key});

  final SessionController sessionController;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (BuildContext context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...FlutterDefenderLocalizations.localizationsDelegates,
          ],
          supportedLocales: mergeFlutterDefenderSupportedLocales(const <Locale>[
            Locale('en'),
          ]),
          routes: <String, WidgetBuilder>{
            '/': (_) => HomeScreen(sessionController: sessionController),
            '/sensitive': (_) => const FlutterDefenderSensitiveGuard(
              child: SensitiveDemoScreen(),
            ),
            '/custom-blocking': (_) => const FlutterDefenderSensitiveGuard(
              child: CustomBlockingDemoScreen(),
            ),
            '/otp': (_) =>
                const FlutterDefenderOtpGuard(child: OtpDemoScreen()),
            '/authenticated': (_) => FlutterDefenderSensitiveGuard(
              child: AuthenticatedDemoScreen(
                sessionController: sessionController,
              ),
            ),
          },
        );
      },
    );
  }
}

Widget buildExampleBlockingScreen(String message) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FlutterLogo(size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This demo keeps the barrier active so taps never reach the protected screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB2C6DC), height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}
