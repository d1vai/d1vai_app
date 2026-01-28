import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/env_var.dart';
import '../../providers/auth_provider.dart';
import '../../screens/project_api_keys_screen.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';
import 'env_var_editor_dialog.dart';

/// 项目详情页 - API Tab（环境变量 + API 工具）
class ProjectApiTab extends StatefulWidget {
  final String projectId;

  const ProjectApiTab({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectApiTab> createState() => _ProjectApiTabState();
}

class _ProjectApiTabState extends State<ProjectApiTab> {
  final List<EnvVar> _envVars = [];
  bool _isLoadingEnvVars = false;
  bool _isInitialized = false;
  String? _loadError;
  bool _showValues = false;
  bool _exporting = false;
  bool _importing = false;
  bool _syncingVercel = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadEnvVars();
    }
  }

  Future<void> _loadEnvVars() async {
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
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
      );
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
      SnackBarHelper.showError(
        context,
        title: 'Create failed',
        message: msg,
      );
    }
  }

  Future<EnvVar?> _fetchEnvVarWithValue(EnvVar envVar) async {
    // If list already includes values, just use it.
    final v = (envVar.value ?? '').trim();
    if (v.isNotEmpty && v != '***') return envVar;

    try {
      final service = D1vaiService();
      final data = await service.listEnvVars(widget.projectId, showValues: true);
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
      builder: (context) => EnvVarEditorDialog(
        initial: hydrated,
        allowEditKey: false,
      ),
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
      SnackBarHelper.showError(
        context,
        title: 'Update failed',
        message: msg,
      );
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
      SnackBarHelper.showError(
        context,
        title: 'Delete failed',
        message: msg,
      );
    }
  }

  Future<void> _exportEnvVars() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final service = D1vaiService();
      final res = await service.exportEnvVars(widget.projectId);
      final content =
          (res['content'] ?? res['env'] ?? res['data'] ?? '').toString();
      if (content.trim().isEmpty) {
        throw Exception('Empty export content');
      }
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Exported',
        message: 'Copied .env to clipboard',
        actionLabel: 'Share',
        onActionPressed: () {
          Share.share(content, subject: '${widget.projectId}.env');
        },
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Export failed',
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importEnvVars() async {
    if (_importing) return;
    final controller = TextEditingController();
    var overwrite = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Import .env'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Paste .env content here…',
                      ),
                      maxLines: 10,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: overwrite,
                      onChanged: (v) => setStateDialog(() => overwrite = v),
                      title: const Text('Overwrite existing'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;

    final content = controller.text;
    controller.dispose();
    if (content.trim().isEmpty) return;

    setState(() => _importing = true);
    try {
      final service = D1vaiService();
      final res = await service.batchImportEnvVars(widget.projectId, {
        'env_content': content,
        'overwrite': overwrite,
      });
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Imported',
        message: (res['message'] ?? 'Import completed').toString(),
      );
      await _loadEnvVars();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Import failed',
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _syncToVercel() async {
    if (_syncingVercel) return;
    setState(() => _syncingVercel = true);
    try {
      final service = D1vaiService();
      final res = await service.syncEnvToVercel(widget.projectId);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Synced',
        message: (res['message'] ?? 'Synced to Vercel').toString(),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Sync failed',
        message: humanizeError(e),
      );
    } finally {
      if (mounted) setState(() => _syncingVercel = false);
    }
  }

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        onPressed: _isLoadingEnvVars ? null : _showCreateEnvVarDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
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
                        onChanged:
                            _isLoadingEnvVars
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
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(true),
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
                  if (_isLoadingEnvVars)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_envVars.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No environment variables — add one to get started.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ..._envVars.map(
                      (envVar) => _EnvVarItem(
                        envVar: envVar,
                        onEdit: () => _showEditEnvVarDialog(envVar),
                        onDelete: () => _confirmAndDeleteEnvVar(envVar),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // API Tools
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.key, color: theme.colorScheme.tertiary),
                    title: const Text('API Keys'),
                    subtitle: const Text('Manage your API keys'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectApiKeysScreen(
                            projectId: widget.projectId,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.description, color: theme.colorScheme.secondary),
                    title: const Text('API Documentation'),
                    subtitle: const Text('View API documentation'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.push('/api-docs');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.download, color: theme.colorScheme.primary),
                    title: const Text('Export Variables'),
                    subtitle: const Text('Download all environment variables'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _exporting ? null : _exportEnvVars,
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.upload, color: theme.colorScheme.primary),
                    title: const Text('Import Variables'),
                    subtitle: const Text('Bulk import from .env file'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _importing ? null : _importEnvVars,
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.sync, color: theme.colorScheme.tertiary),
                    title: const Text('Sync to Vercel'),
                    subtitle: const Text('Push env vars to Vercel preview/production'),
                    trailing: _syncingVercel
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _syncingVercel ? null : _syncToVercel,
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
                        Icon(Icons.delete,
                            size: 18, color: theme.colorScheme.error),
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
