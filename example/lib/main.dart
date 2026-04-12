import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';

import 'src/app/example_app.dart';
import 'src/app/session/session_controller.dart';

export 'src/app/example_app.dart';
export 'src/app/session/session_controller.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SessionController sessionController = SessionController();

  await FlutterDefender.instance.init(
    otpBackgroundTimeoutSeconds: 10,
    pinBackgroundTimeoutSeconds: 20,
    onLogoutRequested: () {
      sessionController.handleTimeoutLogout();
      appNavigatorKey.currentState?.popUntil(
        (Route<dynamic> route) => route.isFirst,
      );
    },
    blockingScreenBuilder: buildExampleBlockingScreen,
  );

  runApp(
    MyApp(sessionController: sessionController, navigatorKey: appNavigatorKey),
  );
}
