import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'flutter_defender_localizations_ar.dart';
import 'flutter_defender_localizations_en.dart';
import 'flutter_defender_localizations_es.dart';
import 'flutter_defender_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FlutterDefenderLocalizations
/// returned by `FlutterDefenderLocalizations.of(context)`.
///
/// Applications need to include `FlutterDefenderLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/flutter_defender_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FlutterDefenderLocalizations.localizationsDelegates,
///   supportedLocales: FlutterDefenderLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the FlutterDefenderLocalizations.supportedLocales
/// property.
abstract class FlutterDefenderLocalizations {
  FlutterDefenderLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FlutterDefenderLocalizations? of(BuildContext context) {
    return Localizations.of<FlutterDefenderLocalizations>(
      context,
      FlutterDefenderLocalizations,
    );
  }

  static const LocalizationsDelegate<FlutterDefenderLocalizations> delegate =
      _FlutterDefenderLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @blockingScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Policy'**
  String get blockingScreenTitle;

  /// No description provided for @emulatorReleaseBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: This app cannot run on emulators in release mode.'**
  String get emulatorReleaseBlocked;

  /// No description provided for @screenshotsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Screenshots are not allowed on sensitive screens.'**
  String get screenshotsBlocked;

  /// No description provided for @overlaysBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Screen overlays are not allowed while sensitive content is visible.'**
  String get overlaysBlocked;

  /// No description provided for @screenCaptureBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Screen recording or mirroring is not allowed.'**
  String get screenCaptureBlocked;

  /// No description provided for @foregroundRequired.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Sensitive screens require the app to remain in the foreground.'**
  String get foregroundRequired;

  /// No description provided for @rootOrJailbreakBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: This device security posture is not trusted (root/jailbreak detected).'**
  String get rootOrJailbreakBlocked;

  /// No description provided for @proxyOrVpnBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Proxy or VPN usage is not allowed for this protected screen.'**
  String get proxyOrVpnBlocked;

  /// No description provided for @tamperingBlocked.
  ///
  /// In en, this message translates to:
  /// **'Security Policy: Runtime tampering or debugging was detected.'**
  String get tamperingBlocked;
}

class _FlutterDefenderLocalizationsDelegate
    extends LocalizationsDelegate<FlutterDefenderLocalizations> {
  const _FlutterDefenderLocalizationsDelegate();

  @override
  Future<FlutterDefenderLocalizations> load(Locale locale) {
    return SynchronousFuture<FlutterDefenderLocalizations>(
      lookupFlutterDefenderLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_FlutterDefenderLocalizationsDelegate old) => false;
}

FlutterDefenderLocalizations lookupFlutterDefenderLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return FlutterDefenderLocalizationsAr();
    case 'en':
      return FlutterDefenderLocalizationsEn();
    case 'es':
      return FlutterDefenderLocalizationsEs();
    case 'fr':
      return FlutterDefenderLocalizationsFr();
  }

  throw FlutterError(
    'FlutterDefenderLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
