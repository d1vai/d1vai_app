import 'package:flutter/widgets.dart';

/// Minimal global locale holder to support localization in layers that don't
/// have a BuildContext (e.g. providers/utils).
///
/// This is intentionally tiny: LocaleProvider is the source of truth and should
/// update this whenever the user changes language.
class LocaleBus {
  static Locale _locale = const Locale('en');

  static Locale get locale => _locale;

  /// Returns the full BCP-47 locale tag used by API audit metadata.
  static String get languageTag {
    final language = _locale.languageCode.trim();
    final script = _locale.scriptCode?.trim();
    final country = _locale.countryCode?.trim();
    return [
      language,
      if (script != null && script.isNotEmpty) script,
      if (country != null && country.isNotEmpty) country,
    ].join('-');
  }

  static void set(Locale locale) {
    _locale = locale;
  }
}
