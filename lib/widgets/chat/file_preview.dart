import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'file_preview_utils.dart';
import 'markdown_text.dart';
import 'monaco_code_preview.dart';
import 'project_chat/code_tab/code_tab_code_block.dart';

const int _maxInlineImageBytes = 12 * 1024 * 1024;
const int _maxInlineAudioBytes = 24 * 1024 * 1024;
const int _maxInlineVideoBytes = 40 * 1024 * 1024;

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

  Uint8List? _decodeBinaryBytes() {
    if (!isBinary) return null;
    try {
      return base64Decode(content);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final binaryBytes = _decodeBinaryBytes();

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

    if (isImagePreview(path) && binaryBytes != null) {
      if (sizeBytes > _maxInlineImageBytes) {
        return Center(
          child: _BinaryUnavailableCard(
            path: path,
            sizeBytes: sizeBytes,
            title: 'Image too large to preview inline',
          ),
        );
      }
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 6,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: theme.colorScheme.surface,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Image.memory(
            binaryBytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _BinaryUnavailableCard(
                  path: path,
                  sizeBytes: sizeBytes,
                  title: 'Image preview unavailable',
                ),
          ),
        ),
      );
    }

    if (isVideoPreview(path) && binaryBytes != null) {
      if (sizeBytes > _maxInlineVideoBytes) {
        return Center(
          child: _BinaryUnavailableCard(
            path: path,
            sizeBytes: sizeBytes,
            title: 'Video too large to preview inline',
          ),
        );
      }
      final mimeType = mimeTypeForPath(path) ?? 'video/mp4';
      return _MediaWebPreview(
        dataUri: Uri.dataFromBytes(binaryBytes, mimeType: mimeType).toString(),
        kind: _MediaPreviewKind.video,
      );
    }

    if (isAudioPreview(path) && binaryBytes != null) {
      if (sizeBytes > _maxInlineAudioBytes) {
        return Center(
          child: _BinaryUnavailableCard(
            path: path,
            sizeBytes: sizeBytes,
            title: 'Audio too large to preview inline',
          ),
        );
      }
      final mimeType = mimeTypeForPath(path) ?? 'audio/mpeg';
      return _MediaWebPreview(
        dataUri: Uri.dataFromBytes(binaryBytes, mimeType: mimeType).toString(),
        kind: _MediaPreviewKind.audio,
      );
    }

    if (isBinary) {
      return Center(
        child: _BinaryUnavailableCard(
          path: path,
          sizeBytes: sizeBytes,
          title: 'Binary preview unavailable',
        ),
      );
    }

    if (isMarkdownPreview(path)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Align(
                alignment: Alignment.topLeft,
                child: MarkdownText(text: content),
              ),
            ),
          );
        },
      );
    }

    if (_supportsMonacoPreview(context)) {
      String previewText = content;
      if (isJsonPreview(path)) {
        try {
          previewText = _prettyJson(content);
        } catch (_) {}
      }
      return MonacoCodePreview(path: path, content: previewText);
    }

    return CodeTabCodeBlock(
      filePath: path,
      text: content,
      isBinary: isBinary,
      sizeBytes: sizeBytes,
    );
  }

  bool _supportsMonacoPreview(BuildContext context) {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => true,
      TargetPlatform.iOS => true,
      TargetPlatform.android => true,
      TargetPlatform.windows => true,
      TargetPlatform.linux => false,
      _ => false,
    };
  }
}

class _BinaryUnavailableCard extends StatelessWidget {
  final String path;
  final int sizeBytes;
  final String title;

  const _BinaryUnavailableCard({
    required this.path,
    required this.sizeBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            title,
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
    );
  }
}

enum _MediaPreviewKind { video, audio }

class _MediaWebPreview extends StatelessWidget {
  final String dataUri;
  final _MediaPreviewKind kind;

  const _MediaWebPreview({required this.dataUri, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isVideo = kind == _MediaPreviewKind.video;
    final html = isVideo
        ? '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #111;
        overflow: hidden;
      }
      .wrap {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      video {
        width: 100%;
        height: 100%;
        object-fit: contain;
        background: #111;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <video controls playsinline preload="metadata">
        <source src="__DATA_URI__">
      </video>
    </div>
  </body>
</html>
'''
        : '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #111;
        color: #fff;
        overflow: hidden;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      }
      .wrap {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        box-sizing: border-box;
      }
      .panel {
        width: min(640px, 100%);
        padding: 20px;
        border-radius: 16px;
        background: #1a1a1a;
        border: 1px solid #333;
      }
      audio {
        width: 100%;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="panel">
        <audio controls preload="metadata">
          <source src="__DATA_URI__">
        </audio>
      </div>
    </div>
  </body>
</html>
''';

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: html.replaceFirst('__DATA_URI__', dataUri),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: true,
      ),
    );
  }
}
