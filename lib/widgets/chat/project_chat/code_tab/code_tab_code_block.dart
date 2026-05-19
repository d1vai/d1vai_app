import 'package:flutter/material.dart';

import '../../app_highlight_view.dart';
import 'code_editor_theme_presets.dart';
import 'code_tab_editor_language.dart';

class CodeTabCodeBlock extends StatelessWidget {
  final String? filePath;
  final String text;
  final bool isBinary;
  final int sizeBytes;

  const CodeTabCodeBlock({
    super.key,
    this.filePath,
    required this.text,
    required this.isBinary,
    required this.sizeBytes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightLanguage = highlightLanguageForPath(filePath);
    final isDark = theme.brightness == Brightness.dark;
    final lines = text.split('\n');
    final gutterDigits = lines.length.toString().length.clamp(2, 5);
    final codeTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.25,
      height: 1.3,
    );

    // Avoid heavy highlighting on very large files (keeps scrolling smooth).
    final enableHighlight =
        !isBinary && highlightLanguage != null && text.length <= 200000;
    final highlightTheme = Map<String, TextStyle>.from(
      codeEditorThemePresetById(isDark ? 'vscode_dark' : 'vscode_light')
          .highlightTheme,
    );
    final root = highlightTheme['root'];
    highlightTheme['root'] = (root ?? const TextStyle()).copyWith(
      backgroundColor: theme.colorScheme.surface,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBinary)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.6,
                ),
              ),
              child: Text(
                'Binary file ($sizeBytes bytes). Showing placeholder content.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          if (!isBinary)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: gutterDigits * 8.0 + 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List<Widget>.generate(lines.length, (index) {
                      return SizedBox(
                        height: 16,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    scrollDirection: Axis.horizontal,
                    child: enableHighlight
                        ? RepaintBoundary(
                            child: AppHighlightView(
                              text: text,
                              language: highlightLanguage,
                              theme: highlightTheme,
                              textStyle: codeTextStyle,
                            ),
                          )
                        : SelectableText(text, style: codeTextStyle),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
