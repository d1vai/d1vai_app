import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          IconButton(
            tooltip: 'Copy',
            onPressed: _loading || _log.trim().isEmpty ? null : _copyAll,
            icon: const Icon(Icons.copy),
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
