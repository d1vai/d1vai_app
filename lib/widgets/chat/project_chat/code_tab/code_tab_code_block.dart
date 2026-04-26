import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import 'code_tab_document_preview.dart';

class CodeTabCodeBlock extends StatelessWidget {
  final String? filePath;
  final String text;
  final bool isBinary;
  final int sizeBytes;

  /// When provided alongside a [filePath] that matches a document-preview
  /// type (.pdf, .docx, .xmind), the widget renders a specialised preview
  /// instead of the generic code/binary view.
  final String? projectId;

  /// Optional callback passed through to [CodeTabDocumentPreview] for DOCX /
  /// XMind files that cannot be rendered inline.
  final VoidCallback? onAsk;

  const CodeTabCodeBlock({
    super.key,
    this.filePath,
    required this.text,
    required this.isBinary,
    required this.sizeBytes,
    this.projectId,
    this.onAsk,
  });

  String? _languageForPath(String? path) {
    if (path == null) return null;
    final p = path.toLowerCase();

    if (p.endsWith('.dart')) return 'dart';
    if (p.endsWith('.ts') || p.endsWith('.tsx')) return 'typescript';
    if (p.endsWith('.js') || p.endsWith('.jsx')) return 'javascript';
    if (p.endsWith('.json')) return 'json';
    if (p.endsWith('.md') || p.endsWith('.markdown')) return 'markdown';
    if (p.endsWith('.css')) return 'css';
    if (p.endsWith('.scss')) return 'scss';
    if (p.endsWith('.html') || p.endsWith('.htm')) return 'xml';
    if (p.endsWith('.yml') || p.endsWith('.yaml')) return 'yaml';
    if (p.endsWith('.py')) return 'python';
    if (p.endsWith('.rs')) return 'rust';
    if (p.endsWith('.sql')) return 'sql';
    if (p.endsWith('.sh') || p.endsWith('.bash')) return 'bash';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Delegate to the specialised document preview when projectId is available
    // and the file extension is one we handle (PDF, DOCX, XMind).
    if (projectId != null && isDocumentPreviewType(filePath)) {
      return CodeTabDocumentPreview(
        projectId: projectId!,
        filePath: filePath!,
        sizeBytes: sizeBytes,
        onAsk: onAsk,
      );
    }

    final theme = Theme.of(context);
    final highlightLanguage = _languageForPath(filePath);
    final isDark = theme.brightness == Brightness.dark;
    final codeTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      height: 1.3,
    );

    // Avoid heavy highlighting on very large files (keeps scrolling smooth).
    final enableHighlight =
        !isBinary && highlightLanguage != null && text.length <= 200000;
    final highlightTheme = Map<String, TextStyle>.from(
      isDark ? atomOneDarkTheme : atomOneLightTheme,
    );
    final root = highlightTheme['root'];
    highlightTheme['root'] = (root ?? const TextStyle()).copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBinary)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'Binary file ($sizeBytes bytes). Showing placeholder content.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          if (isBinary) const SizedBox(height: 10),
          if (enableHighlight)
            RepaintBoundary(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: HighlightView(
                  text,
                  language: highlightLanguage,
                  theme: highlightTheme,
                  padding: EdgeInsets.zero,
                  textStyle: codeTextStyle,
                ),
              ),
            )
          else
            SelectableText(text, style: codeTextStyle),
        ],
      ),
    );
  }
}
