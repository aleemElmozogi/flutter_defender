// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flutter_defender_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FlutterDefenderLocalizationsEn extends FlutterDefenderLocalizations {
  FlutterDefenderLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get blockingScreenTitle => 'Security Policy';

  @override
  String get emulatorReleaseBlocked =>
      'Security Policy: This app cannot run on emulators in release mode.';

  @override
  String get screenshotsBlocked =>
      'Security Policy: Screenshots are not allowed on sensitive screens.';

  @override
  String get overlaysBlocked =>
      'Security Policy: Screen overlays are not allowed while sensitive content is visible.';

  @override
  String get screenCaptureBlocked =>
      'Security Policy: Screen recording or mirroring is not allowed.';

  @override
  String get foregroundRequired =>
      'Security Policy: Sensitive screens require the app to remain in the foreground.';

  @override
  String get rootOrJailbreakBlocked =>
      'Security Policy: This device security posture is not trusted (root/jailbreak detected).';

  @override
  String get proxyOrVpnBlocked =>
      'Security Policy: Proxy or VPN usage is not allowed for this protected screen.';

  @override
  String get tamperingBlocked =>
      'Security Policy: Runtime tampering or debugging was detected.';
}
