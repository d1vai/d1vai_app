import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight Markdown renderer optimized for chat.
///
/// Supports:
/// - Paragraphs + line breaks
/// - Headings (#..######)
/// - Block quotes (>)
/// - Unordered/ordered lists (-, *, +, 1.)
/// - Fenced code blocks (```lang)
/// - Inline styles: **bold**, *italic*, `code`, [text](url)
///
/// Designed to be compact (high information density) and borderless.
class MarkdownText extends StatefulWidget {
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
  State<MarkdownText> createState() => _MarkdownTextState();
}

class _MarkdownTextState extends State<MarkdownText> {
  final List<TapGestureRecognizer> _linkRecognizers = [];

  @override
  void didUpdateWidget(MarkdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontSize: 13,
          height: 1.25,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 13,
          height: 1.25,
        );

    // If maxLines is used, fall back to compact inline renderer for predictable truncation.
    if (widget.maxLines != null && widget.maxLines! > 0) {
      return _buildInlineLines(
        context,
        widget.text,
        baseStyle,
        maxLines: widget.maxLines!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildBlocks(context, widget.text, baseStyle),
    );
  }

  List<Widget> _buildBlocks(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    final theme = Theme.of(context);
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];

    bool isBlockStart(String line) {
      final s = line.trimLeft();
      if (s.startsWith('```')) return true;
      if (RegExp(r'^#{1,6}\s+').hasMatch(s)) return true;
      if (s.startsWith('>')) return true;
      if (RegExp(r'^([-*+])\s+').hasMatch(s)) return true;
      if (RegExp(r'^\d+\.\s+').hasMatch(s)) return true;
      return false;
    }

    int i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trimRight();
      final trimmedLeft = line.trimLeft();

      if (trimmedLeft.isEmpty) {
        i += 1;
        continue;
      }

      // Fenced code block
      if (trimmedLeft.startsWith('```')) {
        final lang = trimmedLeft.substring(3).trim();
        i += 1;
        final buf = <String>[];
        while (i < lines.length) {
          final l = lines[i];
          if (l.trimLeft().startsWith('```')) {
            i += 1;
            break;
          }
          buf.add(l);
          i += 1;
        }
        blocks.add(_Block.code(lang: lang, code: buf.join('\n').trimRight()));
        continue;
      }

      // Heading
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmedLeft);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final content = headingMatch.group(2) ?? '';
        blocks.add(_Block.heading(level: level, text: content));
        i += 1;
        continue;
      }

      // Blockquote
      if (trimmedLeft.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length) {
          final l = lines[i].trimRight();
          final s = l.trimLeft();
          if (!s.startsWith('>')) break;
          final after = s.substring(1);
          buf.add(after.startsWith(' ') ? after.substring(1) : after);
          i += 1;
        }
        blocks.add(_Block.quote(text: buf.join('\n').trimRight()));
        continue;
      }

      // List (unordered/ordered)
      final isUnordered = RegExp(r'^([-*+])\s+').hasMatch(trimmedLeft);
      final isOrdered = RegExp(r'^\d+\.\s+').hasMatch(trimmedLeft);
      if (isUnordered || isOrdered) {
        final items = <String>[];
        while (i < lines.length) {
          final l = lines[i].trimRight();
          final s = l.trimLeft();
          if (s.isEmpty) {
            i += 1;
            break;
          }
          if (!(RegExp(r'^([-*+])\s+').hasMatch(s) ||
              RegExp(r'^\d+\.\s+').hasMatch(s))) {
            break;
          }
          final stripped = s.replaceFirst(RegExp(r'^([-*+])\s+'), '');
          final stripped2 = stripped.replaceFirst(RegExp(r'^\d+\.\s+'), '');
          items.add(stripped2);
          i += 1;
        }
        blocks.add(_Block.list(ordered: isOrdered, items: items));
        continue;
      }

      // Paragraph: collect until blank or new block
      final buf = <String>[];
      while (i < lines.length) {
        final l = lines[i].trimRight();
        if (l.trim().isEmpty) break;
        if (buf.isNotEmpty && isBlockStart(l)) break;
        buf.add(l);
        i += 1;
      }
      blocks.add(_Block.paragraph(text: buf.join('\n').trimRight()));
    }

    final widgets = <Widget>[];
    for (final b in blocks) {
      switch (b.kind) {
        case _BlockKind.heading: {
          final scale = switch (b.headingLevel) {
            1 => 1.16,
            2 => 1.10,
            3 => 1.06,
            _ => 1.01,
          };
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                b.text,
                style: baseStyle.copyWith(
                  fontSize: (baseStyle.fontSize ?? 14) * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
          );
          break;
        }
        case _BlockKind.paragraph: {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  style: baseStyle,
                  children: _parseInline(context, b.text, baseStyle),
                ),
              ),
            ),
          );
          break;
        }
        case _BlockKind.list: {
          final bulletStyle = baseStyle.copyWith(
            color: baseStyle.color?.withValues(alpha: 0.9) ??
                theme.colorScheme.onSurface.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
          );
          for (var idx = 0; idx < b.items.length; idx++) {
            final marker = b.ordered ? '${idx + 1}.' : '•';
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: b.ordered ? 22 : 14,
                      child: Text(marker, style: bulletStyle),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: baseStyle,
                          children: _parseInline(
                            context,
                            b.items[idx],
                            baseStyle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          widgets.add(const SizedBox(height: 1));
          break;
        }
        case _BlockKind.quote: {
          final quoteBg = theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.22 : 0.30,
          );
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: quoteBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildBlocks(
                        context,
                        b.text,
                        baseStyle.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        }
        case _BlockKind.code: {
          final bg = theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 0.95,
          );
          final mono = baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 13) - 0.5,
            height: 1.25,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
          );
          final lang = b.lang.trim();
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (lang.isNotEmpty)
                        Text(
                          lang,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      const Spacer(),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: b.code),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied code'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    b.code,
                    style: mono,
                  ),
                ],
              ),
            ),
          );
          break;
        }
      }
    }
    return widgets;
  }

  Widget _buildInlineLines(
    BuildContext context,
    String text,
    TextStyle baseStyle, {
    required int maxLines,
  }) {
    // Keep behavior close to previous implementation for truncation.
    final lines = text.split('\n');
    final limited = lines.take(maxLines).join('\n');
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _parseInline(context, limited, baseStyle),
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _parseInline(
    BuildContext context,
    String input,
    TextStyle baseStyle,
  ) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];

    // Tokenizer for inline segments:
    // - code: `...`
    // - link: [text](url)
    // - bold: **...** or __...__
    // - italic: *...* or _..._
    final patterns = [
      RegExp(r'`([^`]+)`'),
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      RegExp(r'\*\*([^*]+)\*\*'),
      RegExp(r'__([^_]+)__'),
      RegExp(r'\*([^*]+)\*'),
      RegExp(r'_([^_]+)_'),
    ];

    final matches = <RegExpMatch>[];
    for (final p in patterns) {
      matches.addAll(p.allMatches(input));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;
    for (final m in matches) {
      if (m.start < cursor) continue;
      if (m.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, m.start)));
      }

      final raw = m.group(0) ?? '';
      if (raw.startsWith('`')) {
        final code = m.group(1) ?? '';
        spans.add(
          TextSpan(
            text: code,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            ),
          ),
        );
      } else if (raw.startsWith('[')) {
        final label = m.group(1) ?? '';
        final url = (m.group(2) ?? '').trim();
        final rec = TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            final ok = await canLaunchUrl(uri);
            if (!ok) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          };
        _linkRecognizers.add(rec);
        spans.add(
          TextSpan(
            text: label.isNotEmpty ? label : url,
            style: baseStyle.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
            recognizer: rec,
          ),
        );
      } else if (raw.startsWith('**') || raw.startsWith('__')) {
        spans.add(
          TextSpan(
            text: m.group(1) ?? '',
            style: baseStyle.copyWith(fontWeight: FontWeight.w800),
          ),
        );
      } else if (raw.startsWith('*') || raw.startsWith('_')) {
        spans.add(
          TextSpan(
            text: m.group(1) ?? '',
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }

      cursor = m.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }

    return spans;
  }
}

enum _BlockKind { paragraph, heading, list, quote, code }

class _Block {
  final _BlockKind kind;
  final String text;
  final int headingLevel;
  final bool ordered;
  final List<String> items;
  final String lang;
  final String code;

  const _Block._({
    required this.kind,
    this.text = '',
    this.headingLevel = 0,
    this.ordered = false,
    this.items = const [],
    this.lang = '',
    this.code = '',
  });

  factory _Block.paragraph({required String text}) =>
      _Block._(kind: _BlockKind.paragraph, text: text);

  factory _Block.heading({required int level, required String text}) =>
      _Block._(kind: _BlockKind.heading, headingLevel: level, text: text);

  factory _Block.list({required bool ordered, required List<String> items}) =>
      _Block._(kind: _BlockKind.list, ordered: ordered, items: items);

  factory _Block.quote({required String text}) =>
      _Block._(kind: _BlockKind.quote, text: text);

  factory _Block.code({required String lang, required String code}) =>
      _Block._(kind: _BlockKind.code, lang: lang, code: code);
}
