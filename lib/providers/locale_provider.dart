import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;

  // 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('zh'), // Chinese (Simplified)
    Locale('es'), // Spanish
    Locale('ar'), // Arabic
    Locale('fr'), // French
    Locale('ru'), // Russian
  ];

  // 语言名称映射
  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '中文',
    'es': 'Español',
    'ar': 'العربية',
    'fr': 'Français',
    'ru': 'Русский',
  };

  LocaleProvider() {
    _loadLocale();
  }

  /// 从本地存储加载语言设置
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code');
    
    if (languageCode != null) {
      // 使用用户保存的语言
      _locale = Locale(languageCode);
    } else {
      // 使用系统语言，如果不支持则使用英语
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (supportedLocales.any((l) => l.languageCode == systemLocale.languageCode)) {
        _locale = Locale(systemLocale.languageCode);
      } else {
        _locale = const Locale('en');
      }
      // 保存默认语言
      await prefs.setString('language_code', _locale.languageCode);
    }
    
    notifyListeners();
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) {
      return;
    }

    _locale = locale;
    notifyListeners();

    // 保存到本地存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  /// 清除语言设置（恢复系统默认）
  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
    await _loadLocale();
  }

  /// 获取语言名称
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }

  /// 获取当前语言名称
  String get currentLanguageName {
    return languageNames[_locale.languageCode] ?? _locale.languageCode;
  }
}
