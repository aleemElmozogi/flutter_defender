import 'package:flutter/foundation.dart';
import 'package:flutter_defender/flutter_defender.dart';

class SessionController extends ChangeNotifier {
  bool authenticated = false;
  final List<String> eventLog = <String>['Ready'];

  String get lastEvent => eventLog.first;

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
    if (eventLog.length > 6) {
      eventLog.removeRange(6, eventLog.length);
    }
    notifyListeners();
  }
}
