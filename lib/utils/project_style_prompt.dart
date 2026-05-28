import 'package:flutter/material.dart';

import '../models/project.dart';

const String defaultProjectStyleId = '__default_style__';

const String _defaultFollowupPrompt =
    'Read `AGENTS.md` first. Add the new requirements to `PLAN.md`, then complete them together with every unfinished todo. Replace the hello-world page with an MVP and keep going until all checks pass. Think hard.';

const String _zhCnFollowupPrompt =
    '先读 `AGENTS.md`。把新需求添加到 `PLAN.md`，再和现有未完成 todo 一起全部完成，用 MVP 替换 hello-world 页面，直到全部检查通过。think hard。';

const String _zhTwFollowupPrompt =
    '先讀 `AGENTS.md`。把新需求加入 `PLAN.md`，再和目前未完成的 todo 一起全部完成，用 MVP 取代 hello-world 頁面，直到所有檢查通過。think hard。';

String buildStyledProjectPrompt(String basePrompt, ProjectStyleInfo? style) {
  final prompt = basePrompt.trim();
  final suffix = style?.promptSuffix.trim() ?? '';
  if (suffix.isEmpty) return prompt;
  return '$prompt\n\n$suffix';
}

String buildStyledAutoprompt(
  String basePrompt,
  Locale locale,
  ProjectStyleInfo? style,
) {
  final prompt = buildStyledProjectPrompt(basePrompt, style);
  final followup = getProjectAutopromptFollowup(locale);
  if (prompt.isEmpty) return followup;
  return '$prompt\n\n$followup';
}

String getProjectAutopromptFollowup(Locale locale) {
  final tag = _resolveProjectLocaleTag(locale);
  switch (tag) {
    case 'zh-TW':
      return _zhTwFollowupPrompt;
    case 'zh-CN':
      return _zhCnFollowupPrompt;
    default:
      return _defaultFollowupPrompt;
  }
}

String _resolveProjectLocaleTag(Locale locale) {
  if (locale.languageCode == 'zh') {
    final isTraditional =
        locale.scriptCode == 'Hant' ||
        locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'MO';
    return isTraditional ? 'zh-TW' : 'zh-CN';
  }

  final tag = locale.toLanguageTag().trim();
  if (tag.isNotEmpty) return tag;
  return locale.languageCode.trim().isEmpty ? 'en' : locale.languageCode;
}
