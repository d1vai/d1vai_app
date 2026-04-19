import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'file_preview_utils.dart';
import 'markdown_text.dart';
import 'project_chat/code_tab/code_tab_code_block.dart';

class FilePreview extends StatelessWidget {
  final String path;
  final String content;
  final bool isBinary;
  final int sizeBytes;

  const FilePreview({
    super.key,
    required this.path,
    required this.content,
    required this.isBinary,
    required this.sizeBytes,
  });

  String _prettyJson(String raw) {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isBinary && !isSvgPreview(path, content)) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 28,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(height: 10),
              Text(
                'Binary preview unavailable',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$path\n$sizeBytes bytes',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isSvgPreview(path, content)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: SvgPicture.string(
            content,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (isMarkdownPreview(path)) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: MarkdownText(text: content),
      );
    }

    if (isJsonPreview(path)) {
      try {
        return CodeTabCodeBlock(
          filePath: path,
          text: _prettyJson(content),
          isBinary: false,
          sizeBytes: sizeBytes,
        );
      } catch (_) {}
    }

    if (isHtmlPreview(path)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      );
    }

    return CodeTabCodeBlock(
      filePath: path,
      text: content,
      isBinary: isBinary,
      sizeBytes: sizeBytes,
    );
  }
}
