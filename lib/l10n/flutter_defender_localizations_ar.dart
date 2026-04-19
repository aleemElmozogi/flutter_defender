// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flutter_defender_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class FlutterDefenderLocalizationsAr extends FlutterDefenderLocalizations {
  FlutterDefenderLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get blockingScreenTitle => 'حماية البيانات';

  @override
  String get emulatorReleaseBlocked => 'يجب استخدام جهاز حقيقي لتشغيل التطبيق.';

  @override
  String get screenshotsBlocked =>
      'تصوير الشاشة معطل في هذه الصفحة لحماية بياناتك.';

  @override
  String get overlaysBlocked =>
      'هناك تطبيق آخر يغطي الشاشة، يرجى إغلاقه للمتابعة.';

  @override
  String get screenCaptureBlocked =>
      'يرجى إيقاف تسجيل الشاشة أو ميزة العرض اللاسلكي.';

  @override
  String get foregroundRequired =>
      'يجب عدم مغادرة هذه الشاشة حتى اكتمال العملية.';
}
