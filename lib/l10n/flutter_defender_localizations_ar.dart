// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flutter_defender_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class FlutterDefenderLocalizationsAr extends FlutterDefenderLocalizations {
  FlutterDefenderLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get blockingScreenTitle => 'سياسة الأمان';

  @override
  String get emulatorReleaseBlocked =>
      'سياسة الأمان: لا يمكن تشغيل هذا التطبيق على المحاكيات في وضع الإصدار النهائي.';

  @override
  String get screenshotsBlocked =>
      'سياسة الأمان: ليست مسموحة لقطات الشاشة على الشاشات الحساسة.';

  @override
  String get overlaysBlocked =>
      'سياسة الأمان: لا تُسمح بطبقات العرض فوق الشاشة أثناء عرض محتوى حساس.';

  @override
  String get screenCaptureBlocked =>
      'سياسة الأمان: لا يُسمح بتسجيل الشاشة أو عكسها.';

  @override
  String get foregroundRequired =>
      'سياسة الأمان: تتطلب الشاشات الحساسة بقاء التطبيق في المقدمة.';
}
