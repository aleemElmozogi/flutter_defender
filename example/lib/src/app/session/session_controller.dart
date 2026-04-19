import 'package:flutter/foundation.dart';
import 'package:flutter_defender/flutter_defender.dart';

import 'defender_demo_profiles.dart';

class SessionController extends ChangeNotifier {
  bool authenticated = false;
  final List<String> eventLog = <String>['Ready'];
  DefenderDemoProfile activeProfile = DefenderDemoProfile.customBlocking;
  VoidCallback? _logoutHandler;

  String get lastEvent => eventLog.first;

  void registerLogoutHandler(VoidCallback handler) {
    _logoutHandler = handler;
  }

  Future<void> applyProfile(DefenderDemoProfile profile) async {
    final VoidCallback? logoutHandler = _logoutHandler;
    if (logoutHandler == null) {
      throw StateError(
        'registerLogoutHandler() must be called before applying a demo profile.',
      );
    }

    final DefenderDemoProfileConfig config = profile.config;
    await FlutterDefender.instance.init(
      otpBackgroundTimeoutSeconds: 10,
      authenticatedBackgroundTimeoutSeconds: 20,
      enableForegroundCheck: config.enableForegroundCheck,
      enableEmulatorDetectionRelease: config.enableEmulatorDetectionRelease,
      blockingScreenBuilder: config.blockingScreenBuilder,
      onLogoutRequested: logoutHandler,
      uiTheme: config.uiTheme,
      blockingLocale: config.blockingLocale,
      messageResolver: config.messageResolver,
      blockingTitleResolver: config.blockingTitleResolver,
    );

    activeProfile = profile;
    _addEvent('Applied ${profile.label} profile');
  }

  void toggleAuth() {
    authenticated = !authenticated;
    FlutterDefender.instance.setAuthenticated(authenticated);
    _addEvent(
      authenticated
          ? 'Authenticated session enabled'
          : 'Session cleared manually',
    );
  }

  void handleTimeoutLogout() {
    authenticated = false;
    FlutterDefender.instance.setAuthenticated(false);
    _addEvent('Logout requested after background timeout');
  }

  void recordVisit(String message) => _addEvent(message);

  void clearEvents() {
    eventLog
      ..clear()
      ..add('Event log cleared');
    notifyListeners();
  }

  void _addEvent(String message) {
    eventLog.insert(0, message);
    if (eventLog.length > 8) {
      eventLog.removeRange(8, eventLog.length);
    }
    notifyListeners();
  }
}
