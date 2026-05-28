import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/locale_bus.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  // 语言 key 与 Locale 映射
  // 以 AppLocalizations（ARB）支持的语言为准。
  static const Map<String, Locale> _localeMap = {
    'en': Locale('en'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'de': Locale('de'),
    'pt_BR': Locale('pt', 'BR'),
    'pt_PT': Locale('pt', 'PT'),
    'ja': Locale('ja'),
    'ko': Locale('ko'),
    'ru': Locale('ru'),
    'ar': Locale('ar'),
    'hi': Locale('hi'),
    'id': Locale('id'),
    'th': Locale('th'),
    'vi': Locale('vi'),
    'tr': Locale('tr'),
    'it': Locale('it'),
    'nl': Locale('nl'),
    'pl': Locale('pl'),
    'sv': Locale('sv'),
    'cs': Locale('cs'),
    'he': Locale('he'),
    'uk': Locale('uk'),
    'da': Locale('da'),
    'nb': Locale('nb'),
    'fi': Locale('fi'),
    'ro': Locale('ro'),
    'hu': Locale('hu'),
    'el': Locale('el'),
    'bg': Locale('bg'),
    'fa': Locale('fa'),
    'bn': Locale('bn'),
    'ms': Locale('ms'),
    'fil': Locale('fil'),
  };

  static List<Locale> get supportedLocales => _localeMap.values.toList();

  static const List<String> _settingsLanguageKeys = <String>[
    'en',
    'zh',
    'zh_Hant',
    'ja',
    'fr',
    'ru',
    'es',
    'ar',
  ];

  static List<Locale> get settingsSupportedLocales => _settingsLanguageKeys
      .map((key) => _localeMap[key]!)
      .toList(growable: false);

  // 语言名称映射（在语言设置页中展示）
  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt_BR': 'Português (Brasil)',
    'pt_PT': 'Português (Portugal)',
    'ja': '日本語',
    'ko': '한국어',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'tr': 'Türkçe',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'sv': 'Svenska',
    'cs': 'Čeština',
    'he': 'עברית',
    'uk': 'Українська',
    'da': 'Dansk',
    'nb': 'Norsk (Bokmål)',
    'fi': 'Suomi',
    'ro': 'Română',
    'hu': 'Magyar',
    'el': 'Ελληνικά',
    'bg': 'Български',
    'fa': 'فارسی',
    'bn': 'বাংলা',
    'ms': 'Bahasa Melayu',
    'fil': 'Filipino',
  };

  static String languageKeyFromLocale(Locale locale) =>
      _languageKeyFromLocale(locale);

  LocaleProvider() {
    LocaleBus.set(_locale);
    _loadLocale();
  }

  /// 从本地存储加载语言设置
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('language_code');

    if (storedKey != null && _localeMap.containsKey(storedKey)) {
      // 使用用户保存的语言
      _locale = _localeMap[storedKey]!;
    } else {
      // 使用系统语言，如果不支持则使用英语
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final languageKey = _getLanguageKeyFromSystemLocale(systemLocale);

      _locale = _localeMap[languageKey] ?? const Locale('en');

      // 保存默认语言 key
      await prefs.setString('language_code', languageKey);
    }

    LocaleBus.set(_locale);
    notifyListeners();
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    final languageKey = _languageKeyFromLocale(locale);
    if (!_localeMap.containsKey(languageKey)) {
      return;
    }

    _locale = _localeMap[languageKey]!;
    LocaleBus.set(_locale);
    notifyListeners();

    // 保存到本地存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageKey);
  }

  /// 清除语言设置（恢复系统默认）
  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
    await _loadLocale();
  }

  /// 获取语言名称
  String getLanguageName(String languageKey) {
    return languageNames[languageKey] ?? languageKey;
  }

  /// 获取当前语言名称
  String get currentLanguageName {
    final key = _languageKeyFromLocale(_locale);
    return languageNames[key] ?? key;
  }

  /// 从系统 Locale 推断内部语言 key
  String _getLanguageKeyFromSystemLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        // 根据脚本或地区区分简体 / 繁体
        if (locale.scriptCode == 'Hant' ||
            locale.countryCode == 'TW' ||
            locale.countryCode == 'HK' ||
            locale.countryCode == 'MO') {
          return 'zh_Hant';
        }
        return 'zh';
      case 'ja':
        return 'ja';
      case 'ko':
        return 'ko';
      case 'fr':
        return 'fr';
      case 'de':
        return 'de';
      case 'pt':
        return locale.countryCode == 'PT' ? 'pt_PT' : 'pt_BR';
      case 'ru':
        return 'ru';
      case 'es':
        return 'es';
      case 'ar':
        return 'ar';
      case 'hi':
        return 'hi';
      case 'id':
        return 'id';
      case 'th':
        return 'th';
      case 'vi':
        return 'vi';
      case 'tr':
        return 'tr';
      case 'it':
        return 'it';
      case 'nl':
        return 'nl';
      case 'pl':
        return 'pl';
      case 'sv':
        return 'sv';
      case 'cs':
        return 'cs';
      case 'he':
        return 'he';
      case 'uk':
        return 'uk';
      case 'da':
        return 'da';
      case 'nb':
        return 'nb';
      case 'fi':
        return 'fi';
      case 'ro':
        return 'ro';
      case 'hu':
        return 'hu';
      case 'el':
        return 'el';
      case 'bg':
        return 'bg';
      case 'fa':
        return 'fa';
      case 'bn':
        return 'bn';
      case 'ms':
        return 'ms';
      case 'fil':
        return 'fil';
      case 'en':
      default:
        return 'en';
    }
  }

  /// 从 Locale 计算内部语言 key
  static String _languageKeyFromLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO') {
        return 'zh_Hant';
      }
      return 'zh';
    }

    return _localeMap.entries
        .firstWhere(
          (e) =>
              e.value.languageCode == locale.languageCode &&
              (e.value.countryCode ?? '') == (locale.countryCode ?? ''),
          orElse: () => const MapEntry('en', Locale('en')),
        )
        .key;
  }
}
