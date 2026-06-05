import 'package:flutter/widgets.dart';

import '../ui/flutter_defender_message_id.dart';
import '../ui/flutter_defender_ui_theme.dart';

class FlutterDefenderConfig {
  const FlutterDefenderConfig({
    this.otpBackgroundTimeoutSeconds = 60,
    this.authenticatedBackgroundTimeoutSeconds = 120,
    this.enableForegroundCheck = true,
    this.enableEmulatorDetectionRelease = true,
    this.enableRootDetection = false,
    this.enableProxyVpnDetection = false,
    this.enableRaspDetection = false,
    this.enableSecureStorageHelper = false,
    this.clearSecureStorageOnLogout = false,
    this.blockingScreenBuilder,
    this.onLogoutRequested,
    this.onRootDetected,
    this.onProxyOrVpnDetected,
    this.onTamperingDetected,
    this.uiTheme = FlutterDefenderUiTheme.defaults,
    this.blockingLocale,
    this.messageResolver,
    this.blockingTitleResolver,
  });

  factory FlutterDefenderConfig.fromInit({
    required int otpBackgroundTimeoutSeconds,
    required int authenticatedBackgroundTimeoutSeconds,
    required bool enableForegroundCheck,
    required bool enableEmulatorDetectionRelease,
    required bool enableRootDetection,
    required bool enableProxyVpnDetection,
    required bool enableRaspDetection,
    required bool enableSecureStorageHelper,
    required bool clearSecureStorageOnLogout,
    required Widget Function(String message)? blockingScreenBuilder,
    required VoidCallback? onLogoutRequested,
    required VoidCallback? onRootDetected,
    required VoidCallback? onProxyOrVpnDetected,
    required VoidCallback? onTamperingDetected,
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
      authenticatedBackgroundTimeoutSeconds,
      'authenticatedBackgroundTimeoutSeconds',
    );
    return FlutterDefenderConfig(
      otpBackgroundTimeoutSeconds: otpBackgroundTimeoutSeconds,
      authenticatedBackgroundTimeoutSeconds:
          authenticatedBackgroundTimeoutSeconds,
      enableForegroundCheck: enableForegroundCheck,
      enableEmulatorDetectionRelease: enableEmulatorDetectionRelease,
      enableRootDetection: enableRootDetection,
      enableProxyVpnDetection: enableProxyVpnDetection,
      enableRaspDetection: enableRaspDetection,
      enableSecureStorageHelper: enableSecureStorageHelper,
      clearSecureStorageOnLogout: clearSecureStorageOnLogout,
      blockingScreenBuilder: blockingScreenBuilder,
      onLogoutRequested: onLogoutRequested,
      onRootDetected: onRootDetected,
      onProxyOrVpnDetected: onProxyOrVpnDetected,
      onTamperingDetected: onTamperingDetected,
      uiTheme: uiTheme,
      blockingLocale: blockingLocale,
      messageResolver: messageResolver,
      blockingTitleResolver: blockingTitleResolver,
    );
  }

  final int otpBackgroundTimeoutSeconds;
  final int authenticatedBackgroundTimeoutSeconds;
  final bool enableForegroundCheck;
  final bool enableEmulatorDetectionRelease;
  final bool enableRootDetection;
  final bool enableProxyVpnDetection;
  final bool enableRaspDetection;
  final bool enableSecureStorageHelper;
  final bool clearSecureStorageOnLogout;
  final Widget Function(String message)? blockingScreenBuilder;
  final VoidCallback? onLogoutRequested;
  final VoidCallback? onRootDetected;
  final VoidCallback? onProxyOrVpnDetected;
  final VoidCallback? onTamperingDetected;
  final FlutterDefenderUiTheme uiTheme;
  final Locale? blockingLocale;
  final String Function(BuildContext context, FlutterDefenderMessageId id)?
  messageResolver;
  final String Function(BuildContext context)? blockingTitleResolver;
}
