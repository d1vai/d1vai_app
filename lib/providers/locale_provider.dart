import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  // 语言 key 与 Locale 映射
  // 六种常用语言：英语、简体中文、繁体中文、日语、法语、俄语
  static const Map<String, Locale> _localeMap = {
    'en': Locale('en'),
    'zh': Locale('zh'), // 简体中文
    'zh_Hant': Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ), // 繁體中文
    'ja': Locale('ja'),
    'fr': Locale('fr'),
    'ru': Locale('ru'),
  };

  static List<Locale> get supportedLocales => _localeMap.values.toList();

  // 语言名称映射（在语言设置页中展示）
  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
    'ja': '日本語',
    'fr': 'Français',
    'ru': 'Русский',
  };

  static String languageKeyFromLocale(Locale locale) =>
      _languageKeyFromLocale(locale);

  LocaleProvider() {
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

    notifyListeners();
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    final languageKey = _languageKeyFromLocale(locale);
    if (!_localeMap.containsKey(languageKey)) {
      return;
    }

    _locale = _localeMap[languageKey]!;
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
      case 'fr':
        return 'fr';
      case 'ru':
        return 'ru';
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
