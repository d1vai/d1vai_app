import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth_expiry_bus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/env_var.dart';
import '../../services/app_analytics_service.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../adaptive_modal.dart';
import '../app_menu_button.dart';
import '../card.dart';
import '../snackbar_helper.dart';
import 'env_var_editor_dialog.dart';
import 'env_var_loading_skeleton.dart';

class ProjectApiTab extends StatefulWidget {
  final String projectId;

  const ProjectApiTab({super.key, required this.projectId});

  @override
  State<ProjectApiTab> createState() => _ProjectApiTabState();
}

class _ProjectApiTabState extends State<ProjectApiTab> {
  static const Duration _minSkeletonDuration = Duration(milliseconds: 550);

  final List<EnvVar> _envVars = [];
  bool _isLoadingEnvVars = false;
  bool _isInitialized = false;
  String? _loadError;
  bool _showValues = false;
  bool _isSyncing = false;
  bool _isExporting = false;
  bool _isImporting = false;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      unawaited(_loadEnvVars());
    }
  }

  Future<void> _loadEnvVars() async {
    final startedAt = DateTime.now();
    setState(() {
      _isLoadingEnvVars = true;
      _loadError = null;
    });

    try {
      final service = D1vaiService();
      final data = await service.listEnvVars(
        widget.projectId,
        showValues: _showValues,
      );
      if (!mounted) return;

      final vars = data
          .map((item) => EnvVar.fromJson(item as Map<String, dynamic>))
          .toList();

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minSkeletonDuration) {
        await Future.delayed(_minSkeletonDuration - elapsed);
      }
      if (!mounted) return;

      setState(() {
        _envVars
          ..clear()
          ..addAll(vars);
        _isLoadingEnvVars = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      setState(() {
        _isLoadingEnvVars = false;
        _loadError = msg;
      });
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.projectId}/env-vars',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: msg,
      );
    }
  }

  Future<void> _showCreateEnvVarDialog() async {
    final result = await showAdaptiveModal<EnvVarEditorResult>(
      context: context,
      builder: (context) => const EnvVarEditorDialog(),
    );
    if (result == null) return;

    try {
      final service = D1vaiService();
      await service.createEnvVar(widget.projectId, {
        'key': result.key,
        'value': result.value,
        'description': result.description,
        'is_sensitive': result.isSensitive,
      });
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_api_added', 'Added'),
        message: _t(
          'project_api_variable_created',
          'Environment variable created',
        ),
      );
      unawaited(
        AppAnalyticsService.instance.trackEnvVarCreated(
          widget.projectId,
          result.key,
        ),
      );
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_api_create_failed', 'Create failed'),
        message: humanizeError(e),
      );
    }
  }

  Future<EnvVar?> _fetchEnvVarWithValue(EnvVar envVar) async {
    final v = (envVar.value ?? '').trim();
    if (v.isNotEmpty && v != '***') return envVar;

    try {
      final service = D1vaiService();
      final data = await service.listEnvVars(
        widget.projectId,
        showValues: true,
      );
      final vars = data
          .map((item) => EnvVar.fromJson(item as Map<String, dynamic>))
          .toList();
      return vars.firstWhere(
        (x) => x.id != null && x.id == envVar.id,
        orElse: () => envVar,
      );
    } catch (_) {
      return envVar;
    }
  }

  Future<void> _showEditEnvVarDialog(EnvVar envVar) async {
    final hydrated = await _fetchEnvVarWithValue(envVar);
    if (!mounted) return;

    final result = await showAdaptiveModal<EnvVarEditorResult>(
      context: context,
      builder: (context) =>
          EnvVarEditorDialog(initial: hydrated, allowEditKey: false),
    );
    if (result == null || envVar.id == null) return;

    try {
      final service = D1vaiService();
      await service.updateEnvVar(widget.projectId, envVar.id!, {
        'value': result.value,
        'description': result.description,
        'is_sensitive': result.isSensitive,
      });
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_api_saved', 'Saved'),
        message: _t(
          'project_api_variable_updated',
          'Environment variable updated',
        ),
      );
      unawaited(
        AppAnalyticsService.instance.trackEnvVarUpdated(
          widget.projectId,
          envVar.key,
        ),
      );
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_api_update_failed', 'Update failed'),
        message: humanizeError(e),
      );
    }
  }

  Future<void> _confirmAndDeleteEnvVar(EnvVar envVar) async {
    if (envVar.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('project_api_delete_variable', 'Delete variable')),
        content: Text(
          _t(
            'project_api_delete_confirm',
            'Delete {key}? This cannot be undone.',
          ).replaceAll('{key}', envVar.key),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final service = D1vaiService();
      await service.deleteEnvVar(widget.projectId, envVar.id!);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_api_deleted', 'Deleted'),
        message: envVar.key,
      );
      unawaited(
        AppAnalyticsService.instance.trackEnvVarDeleted(
          widget.projectId,
          envVar.key,
        ),
      );
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_api_delete_failed', 'Delete failed'),
        message: humanizeError(e),
      );
    }
  }

  Future<void> _toggleShowValues(bool next) async {
    if (!next) {
      setState(() => _showValues = false);
      await _loadEnvVars();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('project_api_show_values_title', 'Show values?')),
        content: Text(
          _t(
            'project_api_show_values_message',
            'This will reveal sensitive environment values on screen.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('project_api_show', 'Show')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _showValues = true);
    await _loadEnvVars();
  }

  Future<void> _openImportDialog() async {
    final result = await showAdaptiveModal<_ImportEnvResult>(
      context: context,
      builder: (context) => const _ImportEnvDialog(),
    );
    if (result == null) return;

    setState(() => _isImporting = true);
    try {
      final service = D1vaiService();
      final data = await service.batchImportEnvVars(widget.projectId, {
        'env_content': result.content,
        'overwrite': result.overwrite,
      });
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('import_action', 'Import'),
        message:
            'Created ${data['created'] ?? 0} · Updated ${data['updated'] ?? 0} · Skipped ${data['skipped'] ?? 0}',
      );
      unawaited(
        AppAnalyticsService.instance.trackEnvVarImported(
          widget.projectId,
          created: (data['created'] as num?)?.toInt() ?? 0,
          updated: (data['updated'] as num?)?.toInt() ?? 0,
          skipped: (data['skipped'] as num?)?.toInt() ?? 0,
        ),
      );
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('import_action', 'Import'),
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openExportDialog() async {
    setState(() => _isExporting = true);
    try {
      final service = D1vaiService();
      final data = await service.exportEnvVars(widget.projectId);
      if (!mounted) return;
      final content = (data['content'] ?? '').toString();
      final filename = (data['filename'] ?? '${widget.projectId}.env')
          .toString();
      unawaited(AppAnalyticsService.instance.trackEnvVarExported(widget.projectId));
      await showAdaptiveModal<void>(
        context: context,
        builder: (context) =>
            _ExportEnvDialog(filename: filename, content: content),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_api_export', 'Export'),
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _syncToVercel() async {
    setState(() => _isSyncing = true);
    try {
      final service = D1vaiService();
      final data = await service.syncEnvToVercel(widget.projectId);
      if (!mounted) return;
      final message =
          (data['message'] ?? data['detail'] ?? 'Vercel sync completed')
              .toString();
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_api_sync_vercel', 'Sync to Vercel'),
        message: message,
      );
      unawaited(AppAnalyticsService.instance.trackEnvVarSynced(widget.projectId));
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_api_sync_vercel', 'Sync to Vercel'),
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _copyValue(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: _t('copied', 'Copied'),
      message: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skeletonItemCount = _envVars.isEmpty
        ? 4
        : (_envVars.length < 3
              ? 3
              : (_envVars.length > 8 ? 8 : _envVars.length));

    return RefreshIndicator(
      onRefresh: _loadEnvVars,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                'project_api_environment_variables',
                                'Environment Variables',
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Manage runtime secrets, export a full .env snapshot, and keep Vercel in sync from one dense workspace.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _EnvStatPill(
                        label: _t('project_api_total', 'Total'),
                        value: '${_envVars.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoadingEnvVars
                            ? null
                            : () => _toggleShowValues(!_showValues),
                        icon: Icon(
                          _showValues
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          _showValues ? 'Hide Values' : 'Show Values',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isImporting ? null : _openImportDialog,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: const Text('Import'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isExporting ? null : _openExportDialog,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: const Text('Export'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _syncToVercel,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_outlined),
                        label: const Text('Sync to Vercel'),
                      ),
                      FilledButton.icon(
                        onPressed: _isLoadingEnvVars
                            ? null
                            : _showCreateEnvVarDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Variable'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _EnvInlinePill(
                        icon: _showValues
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        text: _showValues
                            ? _t('project_api_values_visible', 'Values visible')
                            : _t('project_api_values_masked', 'Values masked'),
                      ),
                      _EnvInlinePill(
                        icon: Icons.key_rounded,
                        text:
                            '${_envVars.where((e) => e.isSensitive).length} sensitive',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loadError != null && _loadError!.trim().isNotEmpty) ...[
              _EnvErrorBanner(message: _loadError!, onRetry: _loadEnvVars),
              const SizedBox(height: 12),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isLoadingEnvVars
                  ? EnvVarLoadingSkeleton(
                      key: const ValueKey('loading'),
                      itemCount: skeletonItemCount,
                    )
                  : _envVars.isEmpty
                  ? KeyedSubtree(
                      key: const ValueKey('empty'),
                      child: _EnvVarEmptyState(
                        onAdd: _showCreateEnvVarDialog,
                        canAdd: !_isLoadingEnvVars,
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('list'),
                      child: Column(
                        children: _envVars
                            .map(
                              (envVar) => _EnvVarDenseItem(
                                envVar: envVar,
                                showValues: _showValues,
                                onCopy: (text, label) =>
                                    _copyValue(text, label),
                                onEdit: () => _showEditEnvVarDialog(envVar),
                                onDelete: () => _confirmAndDeleteEnvVar(envVar),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvStatPill extends StatelessWidget {
  final String label;
  final String value;

  const _EnvStatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.primary.withValues(alpha: 0.10), cs.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvInlinePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EnvInlinePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _EnvErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _EnvErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EnvVarEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool canAdd;

  const _EnvVarEmptyState({required this.onAdd, required this.canAdd});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.32 : 0.58,
        ),
        theme.colorScheme.surface.withValues(alpha: isDark ? 0.28 : 0.86),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.key_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(context, 'project_api_empty_title', 'No environment variables'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              context,
              'project_api_empty_hint',
              'Create your first key-value pair to configure\nruntime behavior for this project.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              _t(context, 'project_api_add_variable', 'Add variable'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvVarDenseItem extends StatelessWidget {
  final EnvVar envVar;
  final bool showValues;
  final Future<void> Function(String text, String label) onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EnvVarDenseItem({
    required this.envVar,
    required this.showValues,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final value = showValues ? (envVar.value ?? '') : envVar.displayValue;
    final timestamp = (envVar.updatedAt ?? envVar.createdAt ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 4,
                      child: SelectableText(
                        envVar.key,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: SelectableText(
                        value.trim().isEmpty ? '***' : value,
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.2,
                          color: cs.onSurface.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (value.trim().isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => onCopy(value, envVar.key),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                ),
              ],
              const SizedBox(width: 2),
              AppMenuButton<String>(
                tooltip: 'More',
                useFilledBackground: true,
                actions: const [
                  AppMenuAction(
                    value: 'edit',
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                  ),
                  AppMenuAction(
                    value: 'delete',
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    destructive: true,
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
          if ((envVar.description ?? '').trim().isNotEmpty || timestamp.isNotEmpty)
            const SizedBox(height: 6),
          if ((envVar.description ?? '').trim().isNotEmpty || timestamp.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (envVar.description ?? '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _BadgePill(
                        icon: envVar.isSensitive
                            ? Icons.lock_outline
                            : Icons.key_outlined,
                        text: envVar.isSensitive ? 'Sensitive' : 'Plain',
                        color: envVar.isSensitive
                            ? cs.tertiary
                            : cs.onSurfaceVariant,
                      ),
                      _BadgePill(
                        icon: Icons.layers_outlined,
                        text: envVar.environmentLabel,
                        color: envVar.environmentColor,
                      ),
                      if (timestamp.isNotEmpty)
                        _BadgePill(
                          icon: Icons.schedule_outlined,
                          text: timestamp,
                          color: cs.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _BadgePill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportEnvResult {
  final String content;
  final bool overwrite;

  const _ImportEnvResult({required this.content, required this.overwrite});
}

class _ImportEnvDialog extends StatefulWidget {
  const _ImportEnvDialog();

  @override
  State<_ImportEnvDialog> createState() => _ImportEnvDialogState();
}

class _ImportEnvDialogState extends State<_ImportEnvDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _overwrite = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveModalContainer(
      maxWidth: 720,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveModalHeader(
              title: 'Import Environment Variables',
              subtitle:
                  'Paste .env content below. Each line should follow KEY=value.',
              onClose: () => Navigator.of(context).pop(),
            ),
            TextField(
              controller: _controller,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText:
                    'API_KEY=your-api-key\nDATABASE_URL=postgres://...\nNEXT_PUBLIC_URL=https://...',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _overwrite,
              onChanged: (value) => setState(() => _overwrite = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Overwrite existing variables'),
              subtitle: const Text(
                'When enabled, imported keys replace existing values.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                            _ImportEnvResult(
                              content: _controller.text,
                              overwrite: _overwrite,
                            ),
                          ),
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportEnvDialog extends StatelessWidget {
  final String filename;
  final String content;

  const _ExportEnvDialog({required this.filename, required this.content});

  @override
  Widget build(BuildContext context) {
    return AdaptiveModalContainer(
      maxWidth: 760,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveModalHeader(
              title: 'Export .env',
              subtitle: filename,
              onClose: () => Navigator.of(context).pop(),
            ),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 360),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.24),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (!context.mounted) return;
                      SnackBarHelper.showSuccess(
                        context,
                        title: 'Copied',
                        message: filename,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Share.share(content, subject: filename),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
