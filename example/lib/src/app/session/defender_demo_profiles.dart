import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';

enum DefenderDemoProfile {
  customBlocking,
  themedBlocking,
  arabicBlockingLocale,
  resolverOverrides,
  foregroundCheckDisabled,
  emulatorCheckDisabled,
}

class DefenderDemoProfileConfig {
  const DefenderDemoProfileConfig({
    this.enableForegroundCheck = true,
    this.enableEmulatorDetectionRelease = true,
    this.blockingScreenBuilder,
    this.uiTheme = FlutterDefenderUiTheme.defaults,
    this.blockingLocale,
    this.messageResolver,
    this.blockingTitleResolver,
  });

  final bool enableForegroundCheck;
  final bool enableEmulatorDetectionRelease;
  final Widget Function(String message)? blockingScreenBuilder;
  final FlutterDefenderUiTheme uiTheme;
  final Locale? blockingLocale;
  final String Function(BuildContext context, FlutterDefenderMessageId id)?
  messageResolver;
  final String Function(BuildContext context)? blockingTitleResolver;
}

extension DefenderDemoProfilePresentation on DefenderDemoProfile {
  String get label {
    return switch (this) {
      DefenderDemoProfile.customBlocking => 'Custom Builder',
      DefenderDemoProfile.themedBlocking => 'Theme Override',
      DefenderDemoProfile.arabicBlockingLocale => 'Arabic Locale',
      DefenderDemoProfile.resolverOverrides => 'Message Resolvers',
      DefenderDemoProfile.foregroundCheckDisabled => 'Foreground Check Off',
      DefenderDemoProfile.emulatorCheckDisabled => 'Emulator Check Off',
    };
  }

  String get description {
    return switch (this) {
      DefenderDemoProfile.customBlocking =>
        'Uses blockingScreenBuilder so the host owns the visible content while the plugin still owns the barrier.',
      DefenderDemoProfile.themedBlocking =>
        'Uses the default blocking screen with a custom FlutterDefenderUiTheme.',
      DefenderDemoProfile.arabicBlockingLocale =>
        'Forces the blocking overlay into Arabic so blockingLocale can be verified without changing the app locale.',
      DefenderDemoProfile.resolverOverrides =>
        'Overrides the blocking title and message strings with host-provided resolvers.',
      DefenderDemoProfile.foregroundCheckDisabled =>
        'Disables foreground-required blocking so guarded routes can be compared with and without that policy.',
      DefenderDemoProfile.emulatorCheckDisabled =>
        'Disables release emulator blocking to verify that policy switch independently.',
    };
  }

  String get checklistHint {
    return switch (this) {
      DefenderDemoProfile.customBlocking =>
        'Open the custom blocking demo route and trigger a blocking condition.',
      DefenderDemoProfile.themedBlocking =>
        'Open a guarded route and trigger a blocking condition to see the themed default overlay.',
      DefenderDemoProfile.arabicBlockingLocale =>
        'Open a guarded route and trigger a blocking condition to confirm the overlay is rendered in Arabic.',
      DefenderDemoProfile.resolverOverrides =>
        'Open a guarded route and trigger a blocking condition to confirm the custom title and message copy.',
      DefenderDemoProfile.foregroundCheckDisabled =>
        'Compare a guarded route before and after backgrounding or focus changes to verify the foreground policy toggle.',
      DefenderDemoProfile.emulatorCheckDisabled =>
        'In a release build on emulator or simulator, compare guarded-route behavior before and after applying this profile.',
    };
  }

  DefenderDemoProfileConfig get config {
    return switch (this) {
      DefenderDemoProfile.customBlocking => DefenderDemoProfileConfig(
        blockingScreenBuilder: buildExampleBlockingScreen,
      ),
      DefenderDemoProfile.themedBlocking => DefenderDemoProfileConfig(
        uiTheme: _themedBlockingUiTheme,
      ),
      DefenderDemoProfile.arabicBlockingLocale => DefenderDemoProfileConfig(
        blockingLocale: const Locale('ar'),
      ),
      DefenderDemoProfile.resolverOverrides => DefenderDemoProfileConfig(
        messageResolver: _resolveBlockingMessage,
        blockingTitleResolver: _resolveBlockingTitle,
      ),
      DefenderDemoProfile.foregroundCheckDisabled =>
        const DefenderDemoProfileConfig(enableForegroundCheck: false),
      DefenderDemoProfile.emulatorCheckDisabled =>
        const DefenderDemoProfileConfig(enableEmulatorDetectionRelease: false),
    };
  }
}

Widget buildExampleBlockingScreen(String message) {
  return ColoredBox(
    color: const Color(0xFF08111C),
    child: Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF122235),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2F4E73)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FlutterLogo(size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This demo keeps the barrier active so taps never reach the protected screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB2C6DC), height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

const FlutterDefenderUiTheme _themedBlockingUiTheme = FlutterDefenderUiTheme(
  backgroundColor: Color(0xFF10261D),
  cardColor: Color(0xFF183729),
  cardBorderColor: Color(0xFF4AA36C),
  titleStyle: TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  ),
  bodyStyle: TextStyle(color: Color(0xFFD8F1DF), fontSize: 16, height: 1.5),
  headerLogo: Icon(Icons.verified_user_outlined, color: Colors.white, size: 68),
);

String _resolveBlockingTitle(BuildContext context) {
  return 'Host Policy Override';
}

String _resolveBlockingMessage(
  BuildContext context,
  FlutterDefenderMessageId id,
) {
  return switch (id) {
    FlutterDefenderMessageId.emulatorReleaseBlocked =>
      'Resolver demo: release builds are intentionally blocked on emulators.',
    FlutterDefenderMessageId.screenshotsBlocked =>
      'Resolver demo: screenshots are blocked while protected content is visible.',
    FlutterDefenderMessageId.overlaysBlocked =>
      'Resolver demo: another app is drawing over this sensitive screen.',
    FlutterDefenderMessageId.screenCaptureBlocked =>
      'Resolver demo: screen recording or mirroring is blocked here.',
    FlutterDefenderMessageId.foregroundRequired =>
      'Resolver demo: this protected route must stay in the foreground.',
  };
}
