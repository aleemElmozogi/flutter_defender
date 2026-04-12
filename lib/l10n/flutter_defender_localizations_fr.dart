// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flutter_defender_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class FlutterDefenderLocalizationsFr extends FlutterDefenderLocalizations {
  FlutterDefenderLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get blockingScreenTitle => 'Politique de sécurité';

  @override
  String get emulatorReleaseBlocked =>
      'Politique de sécurité : cette application ne peut pas s\'exécuter sur un émulateur en mode production.';

  @override
  String get screenshotsBlocked =>
      'Politique de sécurité : les captures d\'écran ne sont pas autorisées sur les écrans sensibles.';

  @override
  String get overlaysBlocked =>
      'Politique de sécurité : les superpositions d\'écran ne sont pas autorisées lorsque du contenu sensible est affiché.';

  @override
  String get screenCaptureBlocked =>
      'Politique de sécurité : l\'enregistrement ou la duplication d\'écran n\'est pas autorisé.';

  @override
  String get foregroundRequired =>
      'Politique de sécurité : les écrans sensibles exigent que l\'application reste au premier plan.';
}
