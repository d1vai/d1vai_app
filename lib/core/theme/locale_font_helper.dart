import 'package:flutter/material.dart';

class LocaleFontHelper {
  LocaleFontHelper._();

  static const String chineseDisplayFontFamily = 'SmileySans';

  static bool useChineseSpecialFont(Locale? locale) {
    return locale?.languageCode == 'zh';
  }

  static String? chineseDisplayFont(BuildContext context) {
    return useChineseSpecialFont(Localizations.localeOf(context))
        ? chineseDisplayFontFamily
        : null;
  }

  static TextStyle? localizedTitleStyle(BuildContext context, TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(fontFamily: chineseDisplayFont(context));
  }

  static String? chineseMonospace(BuildContext context) {
    return useChineseSpecialFont(Localizations.localeOf(context))
        ? 'monospace'
        : null;
  }
}
