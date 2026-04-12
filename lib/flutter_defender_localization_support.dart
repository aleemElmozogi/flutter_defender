import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n/flutter_defender_localizations.dart';

/// Returns [TextDirection.rtl] for locales that are typically right-to-left,
/// otherwise [TextDirection.ltr]. Used when forcing a blocking UI locale.
TextDirection flutterDefenderTextDirectionForLocale(Locale locale) {
  return intl.Bidi.isRtlLanguage(locale.languageCode)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// Merges two locale lists without duplicates (first occurrence wins).
List<Locale> mergeLocaleLists(Iterable<Locale> first, Iterable<Locale> second) {
  final Set<String> seen = <String>{};
  final List<Locale> out = <Locale>[];
  for (final Locale locale in <Locale>[...first, ...second]) {
    final String key =
        '${locale.languageCode}\u001f${locale.scriptCode ?? ''}\u001f${locale.countryCode ?? ''}';
    if (seen.add(key)) {
      out.add(locale);
    }
  }
  return out;
}

/// Merges your app's [appSupportedLocales] with
/// [FlutterDefenderLocalizations.supportedLocales] so `MaterialApp` can list
/// every locale your delegates can load.
List<Locale> mergeFlutterDefenderSupportedLocales(
  List<Locale> appSupportedLocales,
) {
  return mergeLocaleLists(
    appSupportedLocales,
    FlutterDefenderLocalizations.supportedLocales,
  );
}
