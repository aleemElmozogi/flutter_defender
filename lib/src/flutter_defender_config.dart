import 'package:flutter/widgets.dart';

import 'flutter_defender_message_id.dart';
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
    this.blockingLocale,
    this.messageResolver,
    this.blockingTitleResolver,
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
    Locale? blockingLocale,
    String Function(BuildContext context, FlutterDefenderMessageId id)?
        messageResolver,
    String Function(BuildContext context)? blockingTitleResolver,
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
      blockingLocale: blockingLocale,
      messageResolver: messageResolver,
      blockingTitleResolver: blockingTitleResolver,
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

  /// When non-null, the blocking overlay loads defender strings in this locale
  /// via an embedded [Localizations.override], independent of the app
  /// `MaterialApp.locale`. When null, strings follow the surrounding app locale
  /// (you should still register [FlutterDefenderLocalizations.delegate] unless
  /// you use [messageResolver]).
  final Locale? blockingLocale;

  /// When non-null, all blocking message bodies use this callback instead of
  /// generated [FlutterDefenderLocalizations] (for wiring to your own
  /// `AppLocalizations`).
  final String Function(BuildContext context, FlutterDefenderMessageId id)?
      messageResolver;

  /// When non-null, the default [BlockingScreen] title uses this callback
  /// instead of [FlutterDefenderLocalizations.blockingScreenTitle].
  final String Function(BuildContext context)? blockingTitleResolver;
}
