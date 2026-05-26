import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';

import 'file_preview_utils.dart';
import 'markdown_text.dart';
import 'monaco_code_preview.dart';
import 'project_chat/code_tab/code_tab_code_block.dart';

const int _maxInlineImageBytes = 12 * 1024 * 1024;
const int _maxInlineAudioBytes = 24 * 1024 * 1024;
const int _maxInlineVideoBytes = 40 * 1024 * 1024;
const int _maxInlineDocumentBytes = 28 * 1024 * 1024;

class FilePreview extends StatelessWidget {
  final String path;
  final String content;
  final bool isBinary;
  final int sizeBytes;
  final bool preferLightweightTextPreview;
  final bool preferMonacoWhenEditable;
  final void Function(int line, int column)? onActivateTextPosition;

  const FilePreview({
    super.key,
    required this.path,
    required this.content,
    required this.isBinary,
    required this.sizeBytes,
    this.preferLightweightTextPreview = false,
    this.preferMonacoWhenEditable = false,
    this.onActivateTextPosition,
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

  String _normalizedTextPreview() {
    if (isJsonPreview(path)) {
      try {
        return _prettyJson(content);
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final binaryBytes = _decodeBinaryBytes();
    final normalizedTextPreview = _normalizedTextPreview();

    if (preferMonacoWhenEditable &&
        !isBinary &&
        shouldOpenPathDirectlyInMonacoEditor(path) &&
        supportsMonacoTextPreview()) {
      return MonacoCodePreview(
        path: path,
        content: normalizedTextPreview,
        onActivatePosition: onActivateTextPosition,
      );
    }

    if (isMindJsonPreview(path)) {
      return _MindJsonPreview(path: path, content: content);
    }

    if (isXMindPreview(path) && binaryBytes != null) {
      return _XMindPreview(
        path: path,
        sizeBytes: sizeBytes,
        bytes: binaryBytes,
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
      if (shouldPreferBrowserImagePreview(path)) {
        final mimeType = mimeTypeForPath(path) ?? 'image/*';
        return _DocumentWebPreview(
          title: 'Image preview',
          html: _buildBrowserImageHtml(
            Uri.dataFromBytes(binaryBytes, mimeType: mimeType).toString(),
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

    if (isArchivePreview(path) && binaryBytes != null) {
      return _ArchivePreview(
        path: path,
        sizeBytes: sizeBytes,
        bytes: binaryBytes,
      );
    }

    if (isEpubPreview(path) && binaryBytes != null) {
      return _EpubPreview(path: path, sizeBytes: sizeBytes, bytes: binaryBytes);
    }

    if (isPdfPreview(path) && binaryBytes != null) {
      if (sizeBytes > _maxInlineDocumentBytes) {
        return Center(
          child: _BinaryUnavailableCard(
            path: path,
            sizeBytes: sizeBytes,
            title: 'PDF too large to preview inline',
          ),
        );
      }
      return _DocumentWebPreview(
        title: 'PDF preview',
        html: _buildPdfHtml(
          Uri.dataFromBytes(
            binaryBytes,
            mimeType: 'application/pdf',
          ).toString(),
        ),
      );
    }

    if (isDocxPreview(path) && binaryBytes != null) {
      return _DocxPreview(path: path, sizeBytes: sizeBytes, bytes: binaryBytes);
    }

    if (isSpreadsheetPreview(path)) {
      if (fileExtensionForPath(path) == 'csv' ||
          fileExtensionForPath(path) == 'tsv') {
        return _DelimitedTablePreview(
          path: path,
          content: content,
          delimiter: fileExtensionForPath(path) == 'tsv' ? '\t' : ',',
        );
      }
      if (binaryBytes != null) {
        return _SpreadsheetArchivePreview(
          path: path,
          sizeBytes: sizeBytes,
          bytes: binaryBytes,
        );
      }
    }

    if (isPresentationPreview(path) && binaryBytes != null) {
      return _PresentationPreview(
        path: path,
        sizeBytes: sizeBytes,
        bytes: binaryBytes,
      );
    }

    if (isLegacyOfficePreview(path) && binaryBytes != null) {
      return _LegacyOfficePreview(
        path: path,
        sizeBytes: sizeBytes,
        bytes: binaryBytes,
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

    if (isLegacyOfficePreview(path)) {
      return Center(
        child: _BinaryUnavailableCard(
          path: path,
          sizeBytes: sizeBytes,
          title: 'Legacy Office preview is not supported yet',
          message:
              'Use PDF, DOCX, XLSX, or PPTX for inline preview in the app.',
        ),
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

    if (isJsonLinesPreview(path)) {
      return _JsonLinesPreview(path: path, content: content);
    }

    if (isXmlStructuredPreview(path)) {
      return _XmlStructuredPreview(path: path, content: content);
    }

    if (preferLightweightTextPreview) {
      return CodeTabCodeBlock(
        filePath: path,
        text: normalizedTextPreview,
        isBinary: false,
        sizeBytes: sizeBytes,
      );
    }

    if (supportsMonacoTextPreview()) {
      return MonacoCodePreview(
        path: path,
        content: normalizedTextPreview,
        onActivatePosition: onActivateTextPosition,
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

class _BinaryUnavailableCard extends StatelessWidget {
  final String path;
  final int sizeBytes;
  final String title;
  final String? message;

  const _BinaryUnavailableCard({
    required this.path,
    required this.sizeBytes,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
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
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$path\n${_prettyBytes(sizeBytes)}',
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

class _DocumentWebPreview extends StatelessWidget {
  final String title;
  final String html;

  const _DocumentWebPreview({required this.title, required this.html});

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: true,
        disableVerticalScroll: false,
        disableHorizontalScroll: false,
      ),
    );
  }
}

class _DocxPreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _DocxPreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_DocxPreview> createState() => _DocxPreviewState();
}

class _DocxPreviewState extends State<_DocxPreview> {
  String? _html;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final documentXml = _zipString(archive, 'word/document.xml');
      if (documentXml == null) {
        throw StateError('Missing word/document.xml');
      }
      final sharedStyles = _zipString(archive, 'word/styles.xml');
      final html = _docxXmlToHtml(documentXml, sharedStyles: sharedStyles);
      if (!mounted) return;
      setState(() {
        _html = html;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'DOCX preview unavailable',
          message: _error,
        ),
      );
    }
    if (_html == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _DocumentWebPreview(
      title: 'DOCX preview',
      html: _buildRichDocumentHtml(_html!, background: '#fafaf8'),
    );
  }
}

class _DelimitedTablePreview extends StatelessWidget {
  final String path;
  final String content;
  final String delimiter;

  const _DelimitedTablePreview({
    required this.path,
    required this.content,
    required this.delimiter,
  });

  List<List<String>> _parseRows() {
    return const LineSplitter()
        .convert(content)
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => line.split(delimiter).map((cell) => cell.trim()).toList(),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _parseRows();
    if (rows.isEmpty) {
      return const Center(child: Text('No table rows available'));
    }
    return _SimpleTablePreview(title: path.split('/').last, rows: rows);
  }
}

class _ArchivePreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _ArchivePreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_ArchivePreview> createState() => _ArchivePreviewState();
}

class _ArchivePreviewState extends State<_ArchivePreview> {
  List<_ArchiveEntryView>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final entries =
          archive.files
              .map(
                (file) => _ArchiveEntryView(
                  name: file.name,
                  isDirectory: file.isFile == false,
                  sizeBytes: file.size,
                  compressedSizeBytes: 0,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _entries = entries;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Archive preview unavailable',
          message: _error,
        ),
      );
    }
    if (_entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.path.split('/').last} · ${_entries!.length} entries',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _prettyBytes(widget.sizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _entries!.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
              ),
              itemBuilder: (context, index) {
                final entry = _entries![index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    entry.isDirectory
                        ? Icons.folder_open_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 18,
                  ),
                  title: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.isDirectory
                        ? 'folder'
                        : 'size ${_prettyBytes(entry.sizeBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpubPreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _EpubPreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_EpubPreview> createState() => _EpubPreviewState();
}

class _EpubPreviewState extends State<_EpubPreview> {
  List<_EpubChapter>? _chapters;
  String? _error;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final chapters = _parseEpubChapters(archive);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _activeIndex = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'EPUB preview unavailable',
          message: _error,
        ),
      );
    }
    if (_chapters == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chapters!.isEmpty) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'EPUB preview unavailable',
          message: 'No readable chapters were found.',
        ),
      );
    }
    final active = _chapters![_activeIndex.clamp(0, _chapters!.length - 1)];
    return Row(
      children: [
        Container(
          width: 260,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _chapters!.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
            itemBuilder: (context, index) {
              final chapter = _chapters![index];
              final selected = index == _activeIndex;
              return ListTile(
                selected: selected,
                selectedTileColor: theme.colorScheme.primary.withValues(
                  alpha: 0.08,
                ),
                title: Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Chapter ${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  setState(() {
                    _activeIndex = index;
                  });
                },
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    active.text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MindJsonPreview extends StatefulWidget {
  final String path;
  final String content;

  const _MindJsonPreview({required this.path, required this.content});

  @override
  State<_MindJsonPreview> createState() => _MindJsonPreviewState();
}

class _MindJsonPreviewState extends State<_MindJsonPreview> {
  _MindDocument? _document;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MindJsonPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content || oldWidget.path != widget.path) {
      _load();
    }
  }

  void _load() {
    try {
      final document = _parseMindJsonDocument(widget.content);
      setState(() {
        _document = document;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _document = null;
        _error = '$error';
      });
    }
  }

  void _renameNode(String nodeId, String title) {
    final document = _document;
    if (document == null) return;
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) return;
    setState(() {
      _document = document.copyWithNodeTitle(nodeId, nextTitle);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.content.length,
          title: 'Mind map preview unavailable',
          message: _error,
        ),
      );
    }
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _MindMapTreeView(
      title: widget.path.split('/').last,
      root: _document!.root,
      onRenameNode: _renameNode,
      editable: true,
    );
  }
}

class _XMindPreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _XMindPreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_XMindPreview> createState() => _XMindPreviewState();
}

class _XMindPreviewState extends State<_XMindPreview> {
  _MindNode? _root;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final root = _parseXMindRoot(archive);
      if (!mounted) return;
      setState(() {
        _root = root;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _root = null;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'XMind preview unavailable',
          message: _error,
        ),
      );
    }
    if (_root == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _MindMapTreeView(
      title: widget.path.split('/').last,
      root: _root!,
      editable: false,
    );
  }
}

class _MindMapTreeView extends StatelessWidget {
  final String title;
  final _MindNode root;
  final bool editable;
  final void Function(String nodeId, String title)? onRenameNode;

  const _MindMapTreeView({
    required this.title,
    required this.root,
    required this.editable,
    this.onRenameNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              editable ? 'editable' : 'read-only',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MindNodeTile(
          node: root,
          depth: 0,
          editable: editable,
          onRenameNode: onRenameNode,
        ),
      ],
    );
  }
}

class _MindNodeTile extends StatefulWidget {
  final _MindNode node;
  final int depth;
  final bool editable;
  final void Function(String nodeId, String title)? onRenameNode;

  const _MindNodeTile({
    required this.node,
    required this.depth,
    required this.editable,
    this.onRenameNode,
  });

  @override
  State<_MindNodeTile> createState() => _MindNodeTileState();
}

class _MindNodeTileState extends State<_MindNodeTile> {
  bool _expanded = true;
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.node.title);
  }

  @override
  void didUpdateWidget(covariant _MindNodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.title != widget.node.title && !_editing) {
      _controller.text = widget.node.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onRenameNode?.call(widget.node.id, _controller.text);
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final leftPad = 12.0 + widget.depth * 18.0;
    return Padding(
      padding: EdgeInsets.only(left: leftPad, bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: hasChildren
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: hasChildren
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        hasChildren
                            ? (_expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_right_rounded)
                            : Icons.circle,
                        size: hasChildren ? 18 : 8,
                        color: hasChildren
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_editing)
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            onSubmitted: (_) => _commit(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          )
                        else
                          GestureDetector(
                            onDoubleTap: widget.editable
                                ? () {
                                    setState(() {
                                      _editing = true;
                                      _controller.text = node.title;
                                    });
                                  }
                                : null,
                            child: Text(
                              node.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if ((node.note ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            node.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (node.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: node.tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      tag,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.editable && _editing) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _commit,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              if (_expanded && hasChildren) ...[
                const SizedBox(height: 10),
                for (final child in node.children)
                  _MindNodeTile(
                    node: child,
                    depth: widget.depth + 1,
                    editable: widget.editable,
                    onRenameNode: widget.onRenameNode,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JsonLinesPreview extends StatelessWidget {
  final String path;
  final String content;

  const _JsonLinesPreview({required this.path, required this.content});

  List<_JsonLineEntry> _parseEntries() {
    final lines = const LineSplitter().convert(content);
    final entries = <_JsonLineEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        entries.add(_JsonLineEntry(index: i + 1, text: pretty, valid: true));
      } catch (_) {
        entries.add(_JsonLineEntry(index: i + 1, text: raw, valid: false));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _parseEntries();
    return Container(
      color: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: entry.valid
                    ? theme.colorScheme.outlineVariant
                    : theme.colorScheme.error.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Line ${entry.index}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        entry.valid ? 'valid JSON' : 'invalid JSON',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: entry.valid
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    entry.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _XmlStructuredPreview extends StatelessWidget {
  final String path;
  final String content;

  const _XmlStructuredPreview({required this.path, required this.content});

  @override
  Widget build(BuildContext context) {
    try {
      final document = XmlDocument.parse(content);
      final root = document.rootElement;
      return _XmlNodeView(path: path, root: _XmlPreviewNode.fromElement(root));
    } catch (error) {
      return Center(
        child: _BinaryUnavailableCard(
          path: path,
          sizeBytes: content.length,
          title: 'XML preview unavailable',
          message: '$error',
        ),
      );
    }
  }
}

class _LegacyOfficePreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _LegacyOfficePreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_LegacyOfficePreview> createState() => _LegacyOfficePreviewState();
}

class _LegacyOfficePreviewState extends State<_LegacyOfficePreview> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final decoded = latin1.decode(widget.bytes, allowInvalid: true);
      final extracted = _extractLegacyOfficeText(decoded);
      if (!mounted) return;
      setState(() {
        _text = extracted;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Legacy Office preview unavailable',
          message: _error,
        ),
      );
    }
    if (_text == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_text!.trim().isEmpty) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Legacy Office preview unavailable',
          message:
              'The file could not be converted into readable inline text. Converting it to docx/xlsx/pptx will work better.',
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _text!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65),
      ),
    );
  }
}

class _SpreadsheetArchivePreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _SpreadsheetArchivePreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_SpreadsheetArchivePreview> createState() =>
      _SpreadsheetArchivePreviewState();
}

class _SpreadsheetArchivePreviewState
    extends State<_SpreadsheetArchivePreview> {
  List<_NamedRows>? _sheets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final workbookXml = _zipString(archive, 'xl/workbook.xml');
      if (workbookXml == null) {
        throw StateError('Missing xl/workbook.xml');
      }
      final sharedStrings = _parseSharedStrings(
        _zipString(archive, 'xl/sharedStrings.xml'),
      );
      final sheetNames = _parseWorkbookSheetNames(workbookXml);
      final relMap = _parseWorkbookRelationships(
        _zipString(archive, 'xl/_rels/workbook.xml.rels'),
      );
      final sheets = <_NamedRows>[];
      for (final entry in sheetNames) {
        final target = relMap[entry.$2];
        if (target == null) continue;
        final normalizedTarget = target.startsWith('xl/')
            ? target
            : 'xl/${target.replaceFirst(RegExp(r'^/'), '')}';
        final sheetXml = _zipString(archive, normalizedTarget);
        if (sheetXml == null) continue;
        final rows = _parseWorksheetRows(sheetXml, sharedStrings);
        sheets.add(_NamedRows(entry.$1, rows));
      }
      if (!mounted) return;
      setState(() {
        _sheets = sheets;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Spreadsheet preview unavailable',
          message: _error,
        ),
      );
    }
    if (_sheets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sheets!.isEmpty) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Spreadsheet preview unavailable',
          message: 'No readable sheets were found.',
        ),
      );
    }
    return DefaultTabController(
      length: _sheets!.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: TabBar(
              isScrollable: true,
              tabs: _sheets!
                  .map((sheet) => Tab(text: sheet.name))
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: _sheets!
                  .map(
                    (sheet) => _SimpleTablePreview(
                      title: sheet.name,
                      rows: sheet.rows,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresentationPreview extends StatefulWidget {
  final String path;
  final int sizeBytes;
  final Uint8List bytes;

  const _PresentationPreview({
    required this.path,
    required this.sizeBytes,
    required this.bytes,
  });

  @override
  State<_PresentationPreview> createState() => _PresentationPreviewState();
}

class _PresentationPreviewState extends State<_PresentationPreview> {
  List<_PresentationSlide>? _slides;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes, verify: false);
      final entries =
          archive.files
              .where((file) => file.name.startsWith('ppt/slides/slide'))
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));
      final slides = <_PresentationSlide>[];
      for (final file in entries) {
        final content = _archiveFileString(file);
        if (content == null) continue;
        slides.add(_parsePresentationSlide(file.name, content));
      }
      if (!mounted) return;
      setState(() {
        _slides = slides;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Presentation preview unavailable',
          message: _error,
        ),
      );
    }
    if (_slides == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_slides!.isEmpty) {
      return Center(
        child: _BinaryUnavailableCard(
          path: widget.path,
          sizeBytes: widget.sizeBytes,
          title: 'Presentation preview unavailable',
          message: 'No readable slides were found.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _slides!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final slide = _slides![index];
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slide ${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (slide.bullets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final bullet in slide.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6, right: 8),
                            child: Icon(Icons.circle, size: 6),
                          ),
                          Expanded(child: Text(bullet)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SimpleTablePreview extends StatelessWidget {
  final String title;
  final List<List<String>> rows;

  const _SimpleTablePreview({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = rows.first;
    final body = rows.length > 1 ? rows.sublist(1) : const <List<String>>[];
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 56,
                  columns: header
                      .map(
                        (cell) => DataColumn(
                          label: SizedBox(
                            width: 160,
                            child: Text(
                              cell.isEmpty ? '-' : cell,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  rows: body
                      .map(
                        (row) => DataRow(
                          cells: List<DataCell>.generate(
                            header.length,
                            (index) => DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  index < row.length ? row[index] : '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamedRows {
  final String name;
  final List<List<String>> rows;

  const _NamedRows(this.name, this.rows);
}

class _MindDocument {
  final int version;
  final String rootId;
  final Map<String, _MindNodeData> nodes;

  const _MindDocument({
    required this.version,
    required this.rootId,
    required this.nodes,
  });

  _MindNode get root => _buildNode(rootId, <String>{});

  _MindNode _buildNode(String id, Set<String> trail) {
    final data = nodes[id];
    if (data == null) {
      return _MindNode(
        id: id,
        title: 'Missing node: $id',
        note: null,
        tags: const <String>[],
        children: const <_MindNode>[],
      );
    }
    if (trail.contains(id)) {
      return _MindNode(
        id: id,
        title: '${data.title} (cycle)',
        note: data.note,
        tags: data.tags,
        children: const <_MindNode>[],
      );
    }
    final nextTrail = <String>{...trail, id};
    return _MindNode(
      id: data.id,
      title: data.title,
      note: data.note,
      tags: data.tags,
      children: data.children
          .map((childId) => _buildNode(childId, nextTrail))
          .toList(growable: false),
    );
  }

  _MindDocument copyWithNodeTitle(String nodeId, String title) {
    final node = nodes[nodeId];
    if (node == null) return this;
    return _MindDocument(
      version: version,
      rootId: rootId,
      nodes: {
        ...nodes,
        nodeId: node.copyWith(title: title),
      },
    );
  }
}

class _MindNodeData {
  final String id;
  final String title;
  final List<String> children;
  final String? note;
  final List<String> tags;

  const _MindNodeData({
    required this.id,
    required this.title,
    required this.children,
    required this.note,
    required this.tags,
  });

  _MindNodeData copyWith({String? title}) {
    return _MindNodeData(
      id: id,
      title: title ?? this.title,
      children: children,
      note: note,
      tags: tags,
    );
  }
}

class _MindNode {
  final String id;
  final String title;
  final String? note;
  final List<String> tags;
  final List<_MindNode> children;

  const _MindNode({
    required this.id,
    required this.title,
    required this.note,
    required this.tags,
    required this.children,
  });
}

class _ArchiveEntryView {
  final String name;
  final bool isDirectory;
  final int sizeBytes;
  final int compressedSizeBytes;

  const _ArchiveEntryView({
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.compressedSizeBytes,
  });
}

class _EpubChapter {
  final String title;
  final String text;

  const _EpubChapter({required this.title, required this.text});
}

class _JsonLineEntry {
  final int index;
  final String text;
  final bool valid;

  const _JsonLineEntry({
    required this.index,
    required this.text,
    required this.valid,
  });
}

class _XmlPreviewNode {
  final String name;
  final Map<String, String> attributes;
  final String? text;
  final List<_XmlPreviewNode> children;

  const _XmlPreviewNode({
    required this.name,
    required this.attributes,
    required this.text,
    required this.children,
  });

  factory _XmlPreviewNode.fromElement(XmlElement element) {
    final text = element.children
        .whereType<XmlText>()
        .map((node) => node.value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    return _XmlPreviewNode(
      name: element.name.toString(),
      attributes: {
        for (final attr in element.attributes) attr.name.toString(): attr.value,
      },
      text: text.isEmpty ? null : text,
      children: element.children
          .whereType<XmlElement>()
          .map(_XmlPreviewNode.fromElement)
          .toList(growable: false),
    );
  }
}

class _XmlNodeView extends StatelessWidget {
  final String path;
  final _XmlPreviewNode root;

  const _XmlNodeView({required this.path, required this.root});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          path.split('/').last,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _XmlNodeTile(node: root, depth: 0),
      ],
    );
  }
}

class _XmlNodeTile extends StatelessWidget {
  final _XmlPreviewNode node;
  final int depth;

  const _XmlNodeTile({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;
    final header = Row(
      children: [
        Text(
          '<${node.name}>',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        if (node.attributes.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              node.attributes.entries
                  .map((entry) => '${entry.key}="${entry.value}"')
                  .join(' '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final body = Padding(
      padding: EdgeInsets.only(left: 12.0 + depth * 8),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if ((node.text ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                node.text!,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
            if (hasChildren) ...[
              const SizedBox(height: 10),
              for (final child in node.children)
                _XmlNodeTile(node: child, depth: depth + 1),
            ],
          ],
        ),
      ),
    );

    return body;
  }
}

class _PresentationSlide {
  final String title;
  final List<String> bullets;

  const _PresentationSlide({required this.title, required this.bullets});
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

String _buildPdfHtml(String dataUri) {
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        height: 100%;
        background: #111827;
        color: #e5e7eb;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      }
      .shell {
        height: 100%;
        display: flex;
        flex-direction: column;
      }
      .note {
        padding: 10px 14px;
        font-size: 12px;
        background: rgba(17, 24, 39, 0.96);
        border-bottom: 1px solid rgba(255,255,255,0.12);
      }
      iframe {
        flex: 1;
        width: 100%;
        border: 0;
        background: white;
      }
    </style>
  </head>
  <body>
    <div class="shell">
      <div class="note">Embedded PDF preview</div>
      <iframe src="$dataUri"></iframe>
    </div>
  </body>
</html>
''';
}

String _buildBrowserImageHtml(String dataUri) {
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        background:
          linear-gradient(45deg, #e5e7eb 25%, transparent 25%),
          linear-gradient(-45deg, #e5e7eb 25%, transparent 25%),
          linear-gradient(45deg, transparent 75%, #e5e7eb 75%),
          linear-gradient(-45deg, transparent 75%, #e5e7eb 75%);
        background-size: 24px 24px;
        background-position: 0 0, 0 12px, 12px -12px, -12px 0;
      }
      .wrap {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 16px;
        box-sizing: border-box;
      }
      img {
        max-width: 100%;
        max-height: 100%;
        object-fit: contain;
        box-shadow: 0 12px 34px rgba(0,0,0,0.12);
        border-radius: 12px;
        background: transparent;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <img src="$dataUri" alt="image preview" />
    </div>
  </body>
</html>
''';
}

String _buildRichDocumentHtml(String body, {String background = '#ffffff'}) {
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        background: $background;
        color: #111827;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      .doc {
        max-width: 920px;
        margin: 0 auto;
        padding: 24px;
        line-height: 1.7;
        font-size: 15px;
      }
      h1, h2, h3 {
        line-height: 1.25;
        margin: 1.4em 0 0.5em;
      }
      p {
        margin: 0 0 1em;
      }
      ul, ol {
        margin: 0 0 1em 1.25em;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        margin: 1em 0;
      }
      td, th {
        border: 1px solid #d1d5db;
        padding: 8px 10px;
        text-align: left;
        vertical-align: top;
      }
      th {
        background: #f3f4f6;
      }
    </style>
  </head>
  <body>
    <div class="doc">$body</div>
  </body>
</html>
''';
}

String? _zipString(Archive archive, String path) {
  for (final file in archive.files) {
    if (file.name == path) return _archiveFileString(file);
  }
  return null;
}

String? _archiveFileString(ArchiveFile file) {
  try {
    final bytes = file.readBytes();
    if (bytes == null) return null;
    return utf8.decode(List<int>.from(bytes), allowMalformed: true);
  } catch (_) {}
  return null;
}

String _docxXmlToHtml(String xml, {String? sharedStyles}) {
  final document = XmlDocument.parse(xml);
  final paragraphs = document.findAllElements('w:p');
  final blocks = <String>[];
  for (final paragraph in paragraphs) {
    final texts = paragraph
        .findAllElements('w:t')
        .map((item) => item.innerText)
        .join();
    final value = texts.trim();
    if (value.isEmpty) continue;
    if (_isHeadingParagraph(paragraph, sharedStyles)) {
      blocks.add('<h2>${htmlEscape.convert(value)}</h2>');
      continue;
    }
    if (_isListParagraph(paragraph)) {
      blocks.add('<li>${htmlEscape.convert(value)}</li>');
      continue;
    }
    blocks.add('<p>${htmlEscape.convert(value)}</p>');
  }
  final merged = <String>[];
  var openList = false;
  for (final block in blocks) {
    if (block.startsWith('<li>')) {
      if (!openList) {
        merged.add('<ul>');
        openList = true;
      }
      merged.add(block);
    } else {
      if (openList) {
        merged.add('</ul>');
        openList = false;
      }
      merged.add(block);
    }
  }
  if (openList) merged.add('</ul>');
  return merged.join();
}

bool _isHeadingParagraph(XmlElement paragraph, String? sharedStyles) {
  final style = paragraph
      .findElements('w:pPr')
      .expand((node) => node.findElements('w:pStyle'))
      .map((node) => node.getAttribute('w:val') ?? '')
      .join()
      .toLowerCase();
  if (style.contains('heading') || style.startsWith('title')) return true;
  return false;
}

bool _isListParagraph(XmlElement paragraph) {
  return paragraph
      .findElements('w:pPr')
      .expand((node) => node.findElements('w:numPr'))
      .isNotEmpty;
}

List<String> _parseSharedStrings(String? xml) {
  if (xml == null) return const <String>[];
  final document = XmlDocument.parse(xml);
  return document
      .findAllElements('si')
      .map(
        (item) =>
            item.findAllElements('t').map((node) => node.innerText).join(),
      )
      .toList(growable: false);
}

List<(String, String)> _parseWorkbookSheetNames(String xml) {
  final document = XmlDocument.parse(xml);
  return document
      .findAllElements('sheet')
      .map(
        (item) => (
          item.getAttribute('name') ?? 'Sheet',
          item.getAttribute('r:id') ?? '',
        ),
      )
      .toList(growable: false);
}

Map<String, String> _parseWorkbookRelationships(String? xml) {
  if (xml == null) return const <String, String>{};
  final document = XmlDocument.parse(xml);
  final map = <String, String>{};
  for (final rel in document.findAllElements('Relationship')) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) {
      map[id] = target;
    }
  }
  return map;
}

List<List<String>> _parseWorksheetRows(String xml, List<String> sharedStrings) {
  final document = XmlDocument.parse(xml);
  final rows = <List<String>>[];
  var maxColumn = 0;
  for (final row in document.findAllElements('row')) {
    final cells = <int, String>{};
    for (final cell in row.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final column = _columnIndexFromCellRef(ref);
      if (column > maxColumn) maxColumn = column;
      final type = cell.getAttribute('t');
      final valueNode = cell.getElement('v');
      final inlineNode = cell.getElement('is');
      String value = '';
      if (type == 's' && valueNode != null) {
        final index = int.tryParse(valueNode.innerText.trim());
        if (index != null && index >= 0 && index < sharedStrings.length) {
          value = sharedStrings[index];
        }
      } else if (inlineNode != null) {
        value = inlineNode
            .findAllElements('t')
            .map((node) => node.innerText)
            .join();
      } else if (valueNode != null) {
        value = valueNode.innerText;
      }
      cells[column] = value;
    }
    final expanded = List<String>.filled(maxColumn + 1, '');
    for (final entry in cells.entries) {
      if (entry.key >= 0 && entry.key < expanded.length) {
        expanded[entry.key] = entry.value;
      }
    }
    if (expanded.any((cell) => cell.trim().isNotEmpty)) {
      rows.add(expanded);
    }
  }
  return rows;
}

int _columnIndexFromCellRef(String ref) {
  var value = 0;
  for (final rune in ref.runes) {
    final char = String.fromCharCode(rune).toUpperCase();
    final code = char.codeUnitAt(0);
    if (code < 65 || code > 90) break;
    value = value * 26 + (code - 64);
  }
  return value == 0 ? 0 : value - 1;
}

_PresentationSlide _parsePresentationSlide(String path, String xml) {
  final document = XmlDocument.parse(xml);
  final texts = document
      .findAllElements('a:t')
      .map((node) => node.innerText.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final title = texts.isEmpty ? path.split('/').last : texts.first;
  final bullets = texts.length <= 1 ? const <String>[] : texts.sublist(1);
  return _PresentationSlide(title: title, bullets: bullets);
}

_MindDocument _parseMindJsonDocument(String content) {
  final payload = jsonDecode(content);
  if (payload is! Map<String, dynamic>) {
    throw StateError('Mind map JSON must be an object');
  }
  final rootId = (payload['rootId'] ?? '').toString().trim();
  if (rootId.isEmpty) {
    throw StateError('Mind map JSON is missing rootId');
  }
  final rawNodes = payload['nodes'];
  if (rawNodes is! Map) {
    throw StateError('Mind map JSON is missing nodes');
  }
  final nodes = <String, _MindNodeData>{};
  rawNodes.forEach((key, value) {
    if (value is! Map) return;
    final id = (value['id'] ?? key).toString().trim();
    final title = (value['title'] ?? 'Untitled').toString().trim();
    final children = (value['children'] is List)
        ? (value['children'] as List)
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final tags = (value['tags'] is List)
        ? (value['tags'] as List)
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final note = (value['note'] ?? '').toString().trim();
    nodes[id] = _MindNodeData(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
      children: children,
      note: note.isEmpty ? null : note,
      tags: tags,
    );
  });
  if (!nodes.containsKey(rootId)) {
    throw StateError('Mind map root "$rootId" does not exist in nodes');
  }
  return _MindDocument(
    version: payload['version'] is num
        ? (payload['version'] as num).toInt()
        : 1,
    rootId: rootId,
    nodes: nodes,
  );
}

_MindNode _parseXMindRoot(Archive archive) {
  final contentJson = _zipString(archive, 'content.json');
  if (contentJson != null) {
    final decoded = jsonDecode(contentJson);
    final sheets = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['sheets'] is List
              ? decoded['sheets'] as List
              : const []);
    if (sheets.isEmpty) {
      throw StateError('No mind map sheets found in content.json');
    }
    final first = sheets.first;
    if (first is! Map<String, dynamic>) {
      throw StateError('Invalid XMind content.json sheet');
    }
    final rootCandidate = first['rootTopic'] ?? first['root'] ?? first['topic'];
    return _parseXMindJsonTopic(rootCandidate, fallbackId: 'root');
  }

  final contentXml = _zipString(archive, 'content.xml');
  if (contentXml != null) {
    final document = XmlDocument.parse(contentXml);
    final sheet = document
        .findAllElements('sheet')
        .firstWhere(
          (_) => true,
          orElse: () =>
              throw StateError('No mind map sheets found in content.xml'),
        );
    final rootTopic = sheet
        .findElements('topic')
        .firstWhere(
          (_) => true,
          orElse: () => throw StateError('Invalid XMind XML content'),
        );
    return _parseXMindXmlTopic(rootTopic, fallbackId: 'root');
  }

  throw StateError(
    'Unsupported XMind archive: content.json/content.xml not found',
  );
}

_MindNode _parseXMindJsonTopic(dynamic raw, {required String fallbackId}) {
  if (raw is! Map) {
    return _MindNode(
      id: fallbackId,
      title: 'Untitled topic',
      note: null,
      tags: const <String>[],
      children: const <_MindNode>[],
    );
  }
  final title = (raw['title'] ?? raw['label'] ?? 'Untitled topic')
      .toString()
      .trim();
  final note = _xmindJsonNote(raw['notes']);
  final tags = (raw['labels'] is List)
      ? (raw['labels'] as List)
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
      : const <String>[];
  final children = _xmindJsonChildren(raw['children'])
      .asMap()
      .entries
      .map(
        (entry) => _parseXMindJsonTopic(
          entry.value,
          fallbackId: '$fallbackId-${entry.key + 1}',
        ),
      )
      .toList(growable: false);
  return _MindNode(
    id: (raw['id'] ?? fallbackId).toString(),
    title: title.isEmpty ? 'Untitled topic' : title,
    note: note,
    tags: tags,
    children: children,
  );
}

List<dynamic> _xmindJsonChildren(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    final values = <dynamic>[];
    for (final value in raw.values) {
      if (value is List) {
        values.addAll(value);
      } else if (value is Map && value['topics'] is List) {
        values.addAll(value['topics'] as List);
      } else if (value is Map && value['attached'] is List) {
        values.addAll(value['attached'] as List);
      } else if (value is Map && value['detached'] is List) {
        values.addAll(value['detached'] as List);
      }
    }
    return values;
  }
  return const <dynamic>[];
}

String? _xmindJsonNote(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
  if (raw is Map && raw['plain'] is Map && raw['plain']['content'] != null) {
    final value = raw['plain']['content'].toString().trim();
    return value.isEmpty ? null : value;
  }
  if (raw is Map && raw['plain'] is Map && raw['plain']['text'] != null) {
    final value = raw['plain']['text'].toString().trim();
    return value.isEmpty ? null : value;
  }
  if (raw is Map && raw['realHTMLContent'] != null) {
    final value = raw['realHTMLContent']
        .toString()
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

_MindNode _parseXMindXmlTopic(
  XmlElement element, {
  required String fallbackId,
}) {
  final title = element
      .findElements('title')
      .map((node) => node.innerText.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => 'Untitled topic');
  final labels = element
      .findElements('label')
      .map((entry) => entry.innerText.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
  final notesElement = element.findElements('notes').firstOrNull;
  final notes = notesElement
      ?.findElements('plain')
      .map((node) => node.innerText.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final childrenContainer = element.findElements('children').firstOrNull;
  final childTopics = childrenContainer == null
      ? const <XmlElement>[]
      : childrenContainer
            .findElements('topics')
            .expand((group) => group.findElements('topic'))
            .toList(growable: false);
  final children = childTopics
      .asMap()
      .entries
      .map(
        (entry) => _parseXMindXmlTopic(
          entry.value,
          fallbackId: '$fallbackId-${entry.key + 1}',
        ),
      )
      .toList(growable: false);
  return _MindNode(
    id: (element.getAttribute('id') ?? fallbackId).trim(),
    title: title,
    note: (notes ?? '').isEmpty ? null : notes,
    tags: labels,
    children: children,
  );
}

extension _FirstOrNullElementExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

List<_EpubChapter> _parseEpubChapters(Archive archive) {
  final containerXml = _zipString(archive, 'META-INF/container.xml');
  if (containerXml == null) return const <_EpubChapter>[];
  final containerDoc = XmlDocument.parse(containerXml);
  final rootfilePath = containerDoc
      .findAllElements('rootfile')
      .map((node) => node.getAttribute('full-path') ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (rootfilePath.isEmpty) return const <_EpubChapter>[];
  final opfXml = _zipString(archive, rootfilePath);
  if (opfXml == null) return const <_EpubChapter>[];
  final opfDoc = XmlDocument.parse(opfXml);
  final opfDir = rootfilePath.contains('/')
      ? rootfilePath.substring(0, rootfilePath.lastIndexOf('/'))
      : '';

  final manifest = <String, String>{};
  for (final item in opfDoc.findAllElements('item')) {
    final id = item.getAttribute('id') ?? '';
    final href = item.getAttribute('href') ?? '';
    if (id.isNotEmpty && href.isNotEmpty) {
      manifest[id] = _normalizeArchivePath(opfDir, href);
    }
  }

  final chapters = <_EpubChapter>[];
  for (final itemref in opfDoc.findAllElements('itemref')) {
    final idref = itemref.getAttribute('idref') ?? '';
    final chapterPath = manifest[idref];
    if (chapterPath == null) continue;
    final chapterXml = _zipString(archive, chapterPath);
    if (chapterXml == null) continue;
    final chapterDoc = XmlDocument.parse(chapterXml);
    final title = chapterDoc
        .findAllElements('title')
        .map((node) => node.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final text = chapterDoc.rootElement.descendants
        .whereType<XmlText>()
        .map((node) => node.value.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    if (text.trim().isEmpty) continue;
    chapters.add(
      _EpubChapter(
        title: title.isEmpty ? 'Chapter ${chapters.length + 1}' : title,
        text: text,
      ),
    );
  }
  return chapters;
}

String _normalizeArchivePath(String baseDir, String href) {
  final raw = href.replaceAll('\\', '/');
  final combined = baseDir.isEmpty ? raw : '$baseDir/$raw';
  final segments = <String>[];
  for (final segment in combined.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

String _extractLegacyOfficeText(String input) {
  final normalized = input
      .replaceAll('\u0000', ' ')
      .replaceAll(RegExp(r'[\x01-\x08\x0B-\x1F]'), ' ');
  final matches =
      RegExp(
            r'[A-Za-z0-9\u4e00-\u9fff][A-Za-z0-9\u4e00-\u9fff\s,\.\-_:;/%()\[\]{}@#&\+\*]{2,}',
          )
          .allMatches(normalized)
          .map((match) => match.group(0)!.trim())
          .where((text) => text.length >= 3)
          .toList(growable: false);
  final unique = <String>[];
  final seen = <String>{};
  for (final item in matches) {
    final compact = item.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length < 3) continue;
    if (seen.add(compact)) unique.add(compact);
    if (unique.length >= 240) break;
  }
  return unique.join('\n');
}

String _prettyBytes(int sizeBytes) {
  if (sizeBytes < 1024) return '$sizeBytes bytes';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
