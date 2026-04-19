import 'package:flutter/material.dart';

import 'src/app/example_app.dart';
import 'src/app/session/session_controller.dart';

export 'src/app/example_app.dart';
export 'src/app/session/session_controller.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SessionController sessionController = SessionController();

  sessionController.registerLogoutHandler(() {
    sessionController.handleTimeoutLogout();
    appNavigatorKey.currentState?.popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
  });
  await sessionController.applyProfile(sessionController.activeProfile);

  runApp(
    MyApp(sessionController: sessionController, navigatorKey: appNavigatorKey),
  );
}
