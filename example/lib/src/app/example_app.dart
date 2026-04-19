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
