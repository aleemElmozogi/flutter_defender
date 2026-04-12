import 'package:flutter/material.dart';

class FlutterDefenderNavigatorObserver extends NavigatorObserver
    with ChangeNotifier {
  NavigatorState? _rootNavigatorState;
  NavigatorState? _currentNavigatorState;
  String? _currentRouteName;

  NavigatorState? get currentNavigatorState => _currentNavigatorState;
  NavigatorState? get rootNavigatorState => _rootNavigatorState;
  NavigatorState? get preferredNavigatorState =>
      _currentNavigatorState ?? _rootNavigatorState;
  String? get currentRouteName => _currentRouteName;

  void reset() {
    _rootNavigatorState = null;
    _currentNavigatorState = null;
    _currentRouteName = null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateState(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateState(previousRoute, route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateState(previousRoute, route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateState(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _updateState(topRoute, previousTopRoute);
    super.didChangeTop(topRoute, previousTopRoute);
  }

  void _updateState(Route<dynamic>? route, Route<dynamic>? fallbackRoute) {
    final NavigatorState? navigatorState =
        route?.navigator ?? fallbackRoute?.navigator ?? _currentNavigatorState;
    if (navigatorState != null) {
      _rootNavigatorState = Navigator.of(
        navigatorState.context,
        rootNavigator: true,
      );
    }
    final String? routeName =
        route?.settings.name ?? fallbackRoute?.settings.name;
    if (navigatorState == _currentNavigatorState &&
        routeName == _currentRouteName) {
      return;
    }
    _currentNavigatorState = navigatorState;
    _currentRouteName = routeName;
    notifyListeners();
  }
}
