import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import 'deployment_log_viewer.dart';
import '../snackbar_helper.dart';

class DeploymentLogScreen extends StatefulWidget {
  final String vercelDeploymentId;
  final String title;

  const DeploymentLogScreen({
    super.key,
    required this.vercelDeploymentId,
    required this.title,
  });

  @override
  State<DeploymentLogScreen> createState() => _DeploymentLogScreenState();
}

class _DeploymentLogScreenState extends State<DeploymentLogScreen> {
  bool _loading = false;
  String? _error;
  String _log = '';
  bool? _fromCache;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = D1vaiService();
      final res = await service.getDeploymentLogs(widget.vercelDeploymentId);
      final log = (res['build_log'] ?? '').toString();
      final fromCache = res['from_cache'];

      if (!mounted) return;
      setState(() {
        _log = log;
        _fromCache = fromCache is bool ? fromCache : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e);
        _loading = false;
      });
    }
  }

  Future<void> _copyAll() async {
    try {
      await Clipboard.setData(ClipboardData(text: _log));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Deployment logs copied to clipboard',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Copy failed',
        message: humanizeError(e),
      );
    }
  }

  String _extractErrorSnippet(String log) {
    final raw = log.trimRight();
    if (raw.isEmpty) return '';

    final lines = raw.split('\n');
    final keyword = RegExp(
      r'(error|failed|exception|traceback|fatal|panic|segmentation fault|exit code|status\s*[45]\d\d)',
      caseSensitive: false,
    );

    final hits = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (keyword.hasMatch(lines[i])) hits.add(i);
    }

    // Fallback: last N lines if we can't find obvious error signals.
    if (hits.isEmpty) {
      final start = (lines.length - 120).clamp(0, lines.length);
      return lines.sublist(start).join('\n');
    }

    final first = hits.first;
    final last = hits.last;
    final start = (first - 25).clamp(0, lines.length);
    final end = (last + 25).clamp(0, lines.length);
    final snippet = lines.sublist(start, end).join('\n');

    // Avoid copying an entire megabyte when errors are very noisy.
    const maxChars = 12000;
    if (snippet.length <= maxChars) return snippet;
    return snippet.substring(0, maxChars);
  }

  Future<void> _copyErrorSnippet() async {
    final snippet = _extractErrorSnippet(_log);
    if (snippet.trim().isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: snippet));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Error snippet copied',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Copy failed',
        message: humanizeError(e),
      );
    }
  }

  Future<void> _shareLog({required bool errorsOnly}) async {
    final text = errorsOnly ? _extractErrorSnippet(_log) : _log;
    if (text.trim().isEmpty) return;
    try {
      await Share.share(
        text,
        subject: errorsOnly ? '${widget.title} (errors)' : widget.title,
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Share failed',
        message: humanizeError(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'copy_all':
                  _copyAll();
                  break;
                case 'copy_errors':
                  _copyErrorSnippet();
                  break;
                case 'share_all':
                  _shareLog(errorsOnly: false);
                  break;
                case 'share_errors':
                  _shareLog(errorsOnly: true);
                  break;
              }
            },
            itemBuilder: (context) {
              final disabled = _loading || _log.trim().isEmpty;
              return [
                PopupMenuItem(
                  value: 'copy_all',
                  enabled: !disabled,
                  child: const Row(
                    children: [
                      Icon(Icons.copy, size: 18),
                      SizedBox(width: 10),
                      Text('Copy all'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy_errors',
                  enabled: !disabled,
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, size: 18),
                      SizedBox(width: 10),
                      Text('Copy errors'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'share_all',
                  enabled: !disabled,
                  child: const Row(
                    children: [
                      Icon(Icons.share, size: 18),
                      SizedBox(width: 10),
                      Text('Share all'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share_errors',
                  enabled: !disabled,
                  child: const Row(
                    children: [
                      Icon(Icons.report, size: 18),
                      SizedBox(width: 10),
                      Text('Share errors'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load logs',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: DeploymentLogViewer(log: _log, fromCache: _fromCache),
            ),
    );
  }
}
