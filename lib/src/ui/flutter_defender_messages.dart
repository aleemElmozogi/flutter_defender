import 'package:flutter/widgets.dart';

import '../../l10n/flutter_defender_localizations.dart';
import 'flutter_defender_message_id.dart';

/// English fallbacks when [FlutterDefenderLocalizations] is not registered on
/// the widget tree (for example in tests or minimal host shells).
final class FlutterDefenderMessages {
  FlutterDefenderMessages._();

  static const String blockingScreenTitle = 'Security Policy';

  static const String emulatorReleaseBlocked =
      'Security Policy: This app cannot run on emulators in release mode.';
  static const String screenshotsBlocked =
      'Security Policy: Screenshots are not allowed on sensitive screens.';
  static const String overlaysBlocked =
      'Security Policy: Screen overlays are not allowed while sensitive content is visible.';
  static const String screenCaptureBlocked =
      'Security Policy: Screen recording or mirroring is not allowed.';
  static const String foregroundRequired =
      'Security Policy: Sensitive screens require the app to remain in the foreground.';
  static const String rootOrJailbreakBlocked =
      'Security Policy: This device security posture is not trusted (root/jailbreak detected).';
  static const String proxyOrVpnBlocked =
      'Security Policy: Proxy or VPN usage is not allowed for this protected screen.';
  static const String tamperingBlocked =
      'Security Policy: Runtime tampering or debugging was detected.';

  static String stringFor(FlutterDefenderMessageId id) {
    return switch (id) {
      FlutterDefenderMessageId.emulatorReleaseBlocked => emulatorReleaseBlocked,
      FlutterDefenderMessageId.screenshotsBlocked => screenshotsBlocked,
      FlutterDefenderMessageId.overlaysBlocked => overlaysBlocked,
      FlutterDefenderMessageId.screenCaptureBlocked => screenCaptureBlocked,
      FlutterDefenderMessageId.foregroundRequired => foregroundRequired,
      FlutterDefenderMessageId.rootOrJailbreakBlocked => rootOrJailbreakBlocked,
      FlutterDefenderMessageId.proxyOrVpnBlocked => proxyOrVpnBlocked,
      FlutterDefenderMessageId.tamperingBlocked => tamperingBlocked,
    };
  }

  static String blockingTitleFor(BuildContext context) {
    return FlutterDefenderLocalizations.of(context)?.blockingScreenTitle ??
        blockingScreenTitle;
  }

  static String resolved(BuildContext context, FlutterDefenderMessageId id) {
    final FlutterDefenderLocalizations? loc = FlutterDefenderLocalizations.of(
      context,
    );
    if (loc != null) {
      return switch (id) {
        FlutterDefenderMessageId.emulatorReleaseBlocked =>
          loc.emulatorReleaseBlocked,
        FlutterDefenderMessageId.screenshotsBlocked => loc.screenshotsBlocked,
        FlutterDefenderMessageId.overlaysBlocked => loc.overlaysBlocked,
        FlutterDefenderMessageId.screenCaptureBlocked =>
          loc.screenCaptureBlocked,
        FlutterDefenderMessageId.foregroundRequired => loc.foregroundRequired,
        FlutterDefenderMessageId.rootOrJailbreakBlocked =>
          loc.rootOrJailbreakBlocked,
        FlutterDefenderMessageId.proxyOrVpnBlocked => loc.proxyOrVpnBlocked,
        FlutterDefenderMessageId.tamperingBlocked => loc.tamperingBlocked,
      };
    }
    return stringFor(id);
  }
}
