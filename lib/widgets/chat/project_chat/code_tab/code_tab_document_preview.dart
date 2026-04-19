import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api_client.dart';

/// Returns `true` when [filePath] is one of the document types that receive
/// rich in-app preview treatment: PDF (inline WebView), DOCX, or XMind.
bool isDocumentPreviewType(String? filePath) {
  if (filePath == null) return false;
  final lower = filePath.toLowerCase().trim();
  return lower.endsWith('.pdf') ||
      lower.endsWith('.docx') ||
      lower.endsWith('.xmind');
}

/// Unified document-preview widget used inside the project Code tab.
///
/// * **PDF** – rendered inline via [InAppWebView].  The widget fetches the
///   current auth token from [SharedPreferences] and passes it as an
///   `Authorization: Bearer …` request header so the API gateway accepts the
///   request without a cookie-based session.
/// * **DOCX / XMind** – these formats cannot be rendered by a web engine, so
///   the widget shows a descriptive info card with file metadata.  An optional
///   [onAsk] callback surfaces an *Ask AI about this file* button when
///   provided by the host (e.g. [CodeTabFileViewerPage]).
class CodeTabDocumentPreview extends StatefulWidget {
  final String projectId;
  final String filePath;
  final int sizeBytes;

  /// Optional: invoked when the user taps "Ask AI about this file".
  final VoidCallback? onAsk;

  const CodeTabDocumentPreview({
    super.key,
    required this.projectId,
    required this.filePath,
    required this.sizeBytes,
    this.onAsk,
  });

  @override
  State<CodeTabDocumentPreview> createState() =>
      _CodeTabDocumentPreviewState();
}

class _CodeTabDocumentPreviewState extends State<CodeTabDocumentPreview> {
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString('auth_token') ?? '').trim();
      final token = raw.toLowerCase().startsWith('bearer ')
          ? raw.substring('bearer '.length).trim()
          : raw;
      if (!mounted) return;
      setState(() {
        _token = token.isEmpty ? null : token;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Constructs the authenticated storage download URL for [widget.filePath].
  String get _downloadUrl {
    final clean = widget.filePath.replaceAll(RegExp(r'^/+'), '');
    return '${ApiClient.baseUrl}'
        '/api/projects/storage/${widget.projectId}/files/$clean';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final lower = widget.filePath.toLowerCase().trim();

    if (lower.endsWith('.pdf')) {
      return _PdfView(downloadUrl: _downloadUrl, token: _token);
    }

    return _OfficeDocCard(
      filePath: widget.filePath,
      sizeBytes: widget.sizeBytes,
      isXMind: lower.endsWith('.xmind'),
      onAsk: widget.onAsk,
    );
  }
}

// ─── Inline PDF viewer ────────────────────────────────────────────────────────

class _PdfView extends StatelessWidget {
  final String downloadUrl;
  final String? token;

  const _PdfView({required this.downloadUrl, required this.token});

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      contextMenu: ContextMenu(),
      initialUrlRequest: URLRequest(
        url: WebUri(downloadUrl),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
  }
}

// ─── Info card for DOCX / XMind ──────────────────────────────────────────────

class _OfficeDocCard extends StatelessWidget {
  final String filePath;
  final int sizeBytes;

  /// `true` → XMind file; `false` → DOCX file.
  final bool isXMind;
  final VoidCallback? onAsk;

  const _OfficeDocCard({
    required this.filePath,
    required this.sizeBytes,
    required this.isXMind,
    this.onAsk,
  });

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = filePath.split('/').last;

    final IconData icon;
    final Color color;
    final String typeLabel;

    if (isXMind) {
      icon = Icons.account_tree_outlined;
      color = Colors.green.shade700;
      typeLabel = 'XMind Map';
    } else {
      icon = Icons.article_outlined;
      color = Colors.blue.shade700;
      typeLabel = 'Word Document';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File-type badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),

            // Filename
            Text(
              filename,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),

            // Type pill + size
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _humanSize(sizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Explanation
            Text(
              'This file format cannot be previewed inline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),

            // Ask-AI shortcut (only when the host provides the callback)
            if (onAsk != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Ask AI about this file'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
