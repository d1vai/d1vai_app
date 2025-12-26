import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

class CodeHighlightBlock extends StatelessWidget {
  final String text;
  final String? language;
  final bool terminalStyle;
  final int maxVisibleLines;

  const CodeHighlightBlock({
    super.key,
    required this.text,
    this.language,
    this.terminalStyle = false,
    this.maxVisibleLines = 14,
  });

  String? _inferLanguage(String raw) {
    final s = raw.trimLeft();
    if (s.isEmpty) return null;
    if (s.startsWith('{') || s.startsWith('[')) return 'json';
    if (s.startsWith('diff ') || s.startsWith('+++') || s.startsWith('---')) {
      return 'diff';
    }
    if (s.startsWith('\$ ') ||
        s.contains('\n\$ ') ||
        s.contains('command not found') ||
        s.contains('No such file or directory')) {
      return 'bash';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = language ?? _inferLanguage(text);
    final enableHighlight = lang != null && text.length <= 200000;

    final baseTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      height: 1.3,
      color: terminalStyle
          ? (isDark ? const Color(0xFFE8EEF6) : const Color(0xFF0F172A))
          : theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );

    final bg = terminalStyle
        ? (isDark ? const Color(0xFF0B0F14) : const Color(0xFFF7F8FA))
        : theme.colorScheme.surface;
    final border = terminalStyle
        ? (isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB))
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);

    final highlightTheme = Map<String, TextStyle>.from(
      isDark ? atomOneDarkTheme : atomOneLightTheme,
    );
    final root = highlightTheme['root'] ?? const TextStyle();
    highlightTheme['root'] = root.copyWith(
      backgroundColor: bg,
      fontFamily: baseTextStyle.fontFamily,
      fontSize: baseTextStyle.fontSize,
      height: baseTextStyle.height,
    );

    final lineCount = '\n'.allMatches(text).length + 1;
    final visibleLines = lineCount.clamp(1, maxVisibleLines);
    final lineHeight =
        (baseTextStyle.fontSize ?? 12.5) * (baseTextStyle.height ?? 1.3);
    final boxVerticalPadding = 12.0;
    final boxHorizontalPadding = 12.0;
    final targetHeight =
        (visibleLines * lineHeight) + (boxVerticalPadding * 2);
    final needsScroll = lineCount > maxVisibleLines || text.length > 2800;

    Widget inner;
    if (enableHighlight) {
      inner = SelectionArea(
        child: HighlightView(
          text,
          language: lang!,
          theme: highlightTheme,
          padding: EdgeInsets.zero,
          textStyle: baseTextStyle,
        ),
      );
    } else {
      inner = SelectableText(text, style: baseTextStyle);
    }

    final content = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: inner,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: boxHorizontalPadding,
        vertical: boxVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: needsScroll
          ? SizedBox(
              height: targetHeight.clamp(0.0, 520.0),
              child: SingleChildScrollView(child: content),
            )
          : content,
    );
  }
}

