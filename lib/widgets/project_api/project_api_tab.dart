import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../../models/env_var.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';
import 'env_var_editor_dialog.dart';
import 'env_var_loading_skeleton.dart';

/// 项目详情页 - Environment Tab（环境变量）
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadEnvVars();
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
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.projectId}/env-vars',
        );
        return;
      }
      SnackBarHelper.showError(context, title: 'Error', message: msg);
    }
  }

  Future<void> _showCreateEnvVarDialog() async {
    final result = await showDialog<EnvVarEditorResult>(
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
        title: 'Added',
        message: 'Environment variable created',
      );
      await _loadEnvVars();
    } catch (e) {
      final msg = humanizeError(e);
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Create failed', message: msg);
    }
  }

  Future<EnvVar?> _fetchEnvVarWithValue(EnvVar envVar) async {
    // If list already includes values, just use it.
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
      final found = vars.firstWhere(
        (x) => x.id != null && x.id == envVar.id,
        orElse: () => envVar,
      );
      return found;
    } catch (_) {
      return envVar;
    }
  }

  Future<void> _showEditEnvVarDialog(EnvVar envVar) async {
    final hydrated = await _fetchEnvVarWithValue(envVar);
    if (!mounted) return;
    final result = await showDialog<EnvVarEditorResult>(
      context: context,
      builder: (context) =>
          EnvVarEditorDialog(initial: hydrated, allowEditKey: false),
    );
    if (result == null) return;
    if (envVar.id == null) return;
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
        title: 'Saved',
        message: 'Environment variable updated',
      );
      await _loadEnvVars();
    } catch (e) {
      final msg = humanizeError(e);
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Update failed', message: msg);
    }
  }

  Future<void> _confirmAndDeleteEnvVar(EnvVar envVar) async {
    if (envVar.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete variable'),
          content: Text('Delete ${envVar.key}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      final service = D1vaiService();
      await service.deleteEnvVar(widget.projectId, envVar.id!);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Deleted',
        message: envVar.key,
      );
      await _loadEnvVars();
    } catch (e) {
      final msg = humanizeError(e);
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Delete failed', message: msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skeletonItemCount = _envVars.isEmpty
        ? 4
        : (_envVars.length < 3
              ? 3
              : (_envVars.length > 8 ? 8 : _envVars.length));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment Variables
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Environment Variables',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoadingEnvVars
                            ? null
                            : _showCreateEnvVarDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showValues ? 'Values visible' : 'Values masked',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _showValues,
                        onChanged: _isLoadingEnvVars
                            ? null
                            : (v) async {
                                final shouldShow = v;
                                if (shouldShow) {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Show values?'),
                                        content: const Text(
                                          'This will reveal sensitive environment values on screen.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Show'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (ok != true) return;
                                }
                                setState(() => _showValues = v);
                                await _loadEnvVars();
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadError != null && _loadError!.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loadError!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoadingEnvVars ? null : _loadEnvVars,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
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
                                    (envVar) => _EnvVarItem(
                                      envVar: envVar,
                                      onEdit: () =>
                                          _showEditEnvVarDialog(envVar),
                                      onDelete: () =>
                                          _confirmAndDeleteEnvVar(envVar),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvVarEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool canAdd;

  const _EnvVarEmptyState({required this.onAdd, required this.canAdd});

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.key_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No environment variables',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first key-value pair to configure\nruntime behavior for this project.',
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
            label: const Text('Add variable'),
          ),
        ],
      ),
    );
  }
}

class _EnvVarItem extends StatelessWidget {
  final EnvVar envVar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EnvVarItem({
    required this.envVar,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envVar.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (envVar.description != null)
                      Text(
                        envVar.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                envVar.isSensitive ? Icons.lock : Icons.code,
                size: 14,
                color: envVar.isSensitive
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                envVar.isSensitive ? 'Sensitive' : 'Not sensitive',
                style: TextStyle(
                  fontSize: 11,
                  color: envVar.isSensitive
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (envVar.displayValue.trim().isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: envVar.value?.toString() ?? ''),
                    );
                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Copied',
                      message: envVar.key,
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (envVar.displayValue.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              envVar.displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
