import 'package:flutter/widgets.dart';

import 'flutter_defender_ui_theme.dart';

class FlutterDefenderConfig {
  const FlutterDefenderConfig({
    this.sensitiveRouteSet = const <String>{},
    this.authenticatedRouteSet = const <String>{},
    this.otpRouteName = '',
    this.otpBackgroundTimeoutSeconds = 60,
    this.pinBackgroundTimeoutSeconds = 120,
    this.enableOverlayDetection = true,
    this.enableForegroundCheck = true,
    this.enableEmulatorDetectionRelease = true,
    this.blockingScreenBuilder,
    this.onLogoutRequested,
    this.uiTheme = FlutterDefenderUiTheme.defaults,
  });

  factory FlutterDefenderConfig.fromInit({
    required List<String> sensitiveRoutes,
    required String otpRouteName,
    required List<String> authenticatedRoutes,
    required int otpBackgroundTimeoutSeconds,
    required int pinBackgroundTimeoutSeconds,
    required bool enableOverlayDetection,
    required bool enableForegroundCheck,
    required bool enableEmulatorDetectionRelease,
    required Widget Function(String message)? blockingScreenBuilder,
    required VoidCallback? onLogoutRequested,
    FlutterDefenderUiTheme uiTheme = FlutterDefenderUiTheme.defaults,
  }) {
    return FlutterDefenderConfig(
      sensitiveRouteSet: Set<String>.unmodifiable(sensitiveRoutes),
      authenticatedRouteSet: Set<String>.unmodifiable(authenticatedRoutes),
      otpRouteName: otpRouteName,
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      pinBackgroundTimeoutSeconds: pinBackgroundTimeoutSeconds,
      enableOverlayDetection: enableOverlayDetection,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      uiTheme: uiTheme,
    );
  }

  final Set<String> sensitiveRouteSet;
  final Set<String> authenticatedRouteSet;
  final String otpRouteName;
  final int otpBackgroundTimeoutSeconds;
  final int pinBackgroundTimeoutSeconds;
  final bool enableOverlayDetection;
  final bool enableForegroundCheck;
  final bool enableEmulatorDetectionRelease;
  final Widget Function(String message)? blockingScreenBuilder;
  final VoidCallback? onLogoutRequested;
  final FlutterDefenderUiTheme uiTheme;
}
