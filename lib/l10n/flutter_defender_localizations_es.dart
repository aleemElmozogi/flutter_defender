// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flutter_defender_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class FlutterDefenderLocalizationsEs extends FlutterDefenderLocalizations {
  FlutterDefenderLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get blockingScreenTitle => 'Política de seguridad';

  @override
  String get emulatorReleaseBlocked =>
      'Política de seguridad: esta aplicación no puede ejecutarse en emuladores en modo release.';

  @override
  String get screenshotsBlocked =>
      'Política de seguridad: no se permiten capturas de pantalla en pantallas sensibles.';

  @override
  String get overlaysBlocked =>
      'Política de seguridad: no se permiten superposiciones de pantalla mientras el contenido sensible está visible.';

  @override
  String get screenCaptureBlocked =>
      'Política de seguridad: no se permite la grabación o duplicación de pantalla.';

  @override
  String get foregroundRequired =>
      'Política de seguridad: las pantallas sensibles requieren que la aplicación permanezca en primer plano.';

  @override
  String get rootOrJailbreakBlocked =>
      'Política de seguridad: no se confía en el estado del dispositivo (se detectó root/jailbreak).';

  @override
  String get proxyOrVpnBlocked =>
      'Política de seguridad: no se permite usar proxy o VPN en esta pantalla protegida.';

  @override
  String get tamperingBlocked =>
      'Política de seguridad: se detectó manipulación en tiempo de ejecución o depuración.';
}
