import 'package:flutter/material.dart';

/// Simple markdown renderer for basic text formatting
class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  const MarkdownText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return _buildMarkdownText(
      context,
      text,
      style: style ??
          TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16.0,
          ),
    );
  }

  Widget _buildMarkdownText(
    BuildContext context,
    String text, {
    required TextStyle style,
  }) {
    if (maxLines != null && maxLines! > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormattedText(context, text, style, maxLines: maxLines!),
        ],
      );
    }

    return _buildFormattedText(context, text, style);
  }

  Widget _buildFormattedText(
    BuildContext context,
    String text,
    TextStyle baseStyle, {
    int? maxLines,
  }) {
    List<Widget> widgets = [];
    List<TextSpan> spans = [];

    final lines = text.split('\n');

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final lineSpans = _parseMarkdownLine(context, line, baseStyle);
      spans.addAll(lineSpans);

      // Add line break if not the last line
      if (lineIndex < lines.length - 1) {
        widgets.add(
          RichText(
            text: TextSpan(children: spans, style: baseStyle),
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        );
        widgets.add(const SizedBox(height: 4));
        spans = [];
      }
    }

    // Add remaining spans
    if (spans.isNotEmpty) {
      widgets.add(
        RichText(
          text: TextSpan(children: spans, style: baseStyle),
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<TextSpan> _parseMarkdownLine(
    BuildContext context,
    String line,
    TextStyle baseStyle,
  ) {
    List<TextSpan> spans = [];

    // Pattern matching for markdown elements
    final patterns = [
      // Inline code: `code`
      RegExp(r'`([^`]+)`'),
      // Bold: **text** or __text__
      RegExp(r'\*\*([^*]+)\*\*'),
      RegExp(r'__([^_]+)__'),
      // Italic: *text* or _text_ (but not __)
      RegExp(r'\*([^*]+)\*'),
      RegExp(r'_([^_]+)_'),
      // Links: [text](url)
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    ];

    List<RegExpMatch> matches = [];
    for (var pattern in patterns) {
      matches.addAll(pattern.allMatches(line).toList());
    }

    // Sort matches by start index
    matches.sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;

    for (var match in matches) {
      if (match.start > cursor) {
        // Add plain text before the match
        String plainText = line.substring(cursor, match.start);
        spans.add(TextSpan(text: plainText, style: baseStyle));
      }

      String matched = match.group(0)!;

      if (matched.startsWith('`')) {
        // Inline code
        String code = match.group(1)!;
        spans.add(
          TextSpan(
            text: code,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      } else if (matched.startsWith('**') || matched.startsWith('__')) {
        // Bold
        String bold = match.group(1)!;
        spans.add(
          TextSpan(
            text: bold,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matched.startsWith('*') || matched.startsWith('_')) {
        // Italic
        String italic = match.group(1)!;
        spans.add(
          TextSpan(
            text: italic,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matched.startsWith('[')) {
        // Link
        String linkText = match.group(1)!;
        spans.add(
          TextSpan(
            text: linkText,
            style: baseStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: null,
          ),
        );
      }

      cursor = match.end;
    }

    // Add remaining text
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}
