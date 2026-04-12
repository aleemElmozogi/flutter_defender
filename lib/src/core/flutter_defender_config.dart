import 'package:flutter/widgets.dart';

import '../ui/flutter_defender_message_id.dart';
import '../ui/flutter_defender_ui_theme.dart';

class FlutterDefenderConfig {
  const FlutterDefenderConfig({
    this.otpBackgroundTimeoutSeconds = 60,
    this.pinBackgroundTimeoutSeconds = 120,
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
    required int otpBackgroundTimeoutSeconds,
    required int pinBackgroundTimeoutSeconds,
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
    RangeError.checkNotNegative(
      otpBackgroundTimeoutSeconds,
      'otpBackgroundTimeoutSeconds',
    );
    RangeError.checkNotNegative(
      pinBackgroundTimeoutSeconds,
      'pinBackgroundTimeoutSeconds',
    );
    return FlutterDefenderConfig(
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      pinBackgroundTimeoutSeconds: pinBackgroundTimeoutSeconds,
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

  final int otpBackgroundTimeoutSeconds;
  final int pinBackgroundTimeoutSeconds;
  final bool enableForegroundCheck;
  final bool enableEmulatorDetectionRelease;
  final Widget Function(String message)? blockingScreenBuilder;
  final VoidCallback? onLogoutRequested;
  final FlutterDefenderUiTheme uiTheme;
  final Locale? blockingLocale;
  final String Function(BuildContext context, FlutterDefenderMessageId id)?
  messageResolver;
  final String Function(BuildContext context)? blockingTitleResolver;
}
