import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

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

  String? _languageForPath(String? path) {
    if (path == null) return null;
    final p = path.toLowerCase();

    if (p.endsWith('.dart')) return 'dart';
    if (p.endsWith('.kt') || p.endsWith('.kts')) return 'kotlin';
    if (p.endsWith('.swift')) return 'swift';
    if (p.endsWith('.ts') || p.endsWith('.tsx')) return 'typescript';
    if (p.endsWith('.js') || p.endsWith('.jsx')) return 'javascript';
    if (p.endsWith('.java')) return 'java';
    if (p.endsWith('.go')) return 'go';
    if (p.endsWith('.c')) return 'c';
    if (p.endsWith('.cc') || p.endsWith('.cpp') || p.endsWith('.cxx')) {
      return 'cpp';
    }
    if (p.endsWith('.h') || p.endsWith('.hpp')) return 'cpp';
    if (p.endsWith('.json')) return 'json';
    if (p.endsWith('.toml')) return 'toml';
    if (p.endsWith('.ini') || p.endsWith('.cfg') || p.endsWith('.conf')) {
      return 'ini';
    }
    if (p.endsWith('.md') || p.endsWith('.markdown')) return 'markdown';
    if (p.endsWith('.css')) return 'css';
    if (p.endsWith('.scss')) return 'scss';
    if (p.endsWith('.less')) return 'less';
    if (p.endsWith('.html') || p.endsWith('.htm')) return 'xml';
    if (p.endsWith('.xml') || p.endsWith('.svg') || p.endsWith('.vue')) {
      return 'xml';
    }
    if (p.endsWith('.yml') || p.endsWith('.yaml')) return 'yaml';
    if (p.endsWith('.py')) return 'python';
    if (p.endsWith('.rs')) return 'rust';
    if (p.endsWith('.sql')) return 'sql';
    if (p.endsWith('.sh') || p.endsWith('.bash')) return 'bash';
    if (p.endsWith('.zsh')) return 'bash';
    if (p.endsWith('.env') ||
        p.endsWith('.env.local') ||
        p.endsWith('.env.production')) {
      return 'bash';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightLanguage = _languageForPath(filePath);
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
      isDark ? vs2015Theme : vsTheme,
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
                            child: HighlightView(
                              text,
                              language: highlightLanguage,
                              theme: highlightTheme,
                              padding: EdgeInsets.zero,
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
