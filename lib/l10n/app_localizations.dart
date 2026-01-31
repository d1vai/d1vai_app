import 'package:flutter/material.dart';

import 'generated_localizations.dart';

/// Lightweight runtime localizations.
///
/// Source of truth lives in `lib/l10n/arb/*.arb`.
/// Do NOT edit translations here; run:
///   dart run tool/gen_l10n.dart
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static String _localeKeyFromLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO') {
        return 'zh_Hant';
      }
      return 'zh';
    }

    return locale.languageCode;
  }

  String translate(String key) {
    final localeKey = _localeKeyFromLocale(locale);
    return kLocalizedValues[localeKey]?[key] ??
        kLocalizedValues['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final localeKey = AppLocalizations._localeKeyFromLocale(locale);
    return kSupportedLocaleKeys.contains(localeKey);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
