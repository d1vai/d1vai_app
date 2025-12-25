import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/env_var.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';

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
      final data = await service.listEnvVars(widget.projectId, showValues: false);
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
                        onPressed: () {
                          SnackBarHelper.showInfo(
                            context,
                            title: 'Add Environment Variable',
                            message: 'Add new environment variable...',
                          );
                        },
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
                      (envVar) => _EnvVarItem(envVar: envVar),
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
                      SnackBarHelper.showInfo(
                        context,
                        title: 'API Keys',
                        message: 'API key management coming soon',
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
                      SnackBarHelper.showInfo(
                        context,
                        title: 'API Documentation',
                        message: 'Documentation coming soon',
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.download, color: theme.colorScheme.primary),
                    title: const Text('Export Variables'),
                    subtitle: const Text('Download all environment variables'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Export',
                        message: 'Exporting environment variables...',
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.upload, color: theme.colorScheme.primary),
                    title: const Text('Import Variables'),
                    subtitle: const Text('Bulk import from .env file'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Import',
                        message: 'Import environment variables...',
                      );
                    },
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

  const _EnvVarItem({
    required this.envVar,
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
              if (envVar.environment != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: envVar.environmentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: envVar.environmentColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    envVar.environmentLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: envVar.environmentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Edit Variable',
                      message: 'Editing ${envVar.key}...',
                    );
                  } else if (value == 'delete') {
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Delete Variable',
                      message: 'Deleting ${envVar.key}...',
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                envVar.isEncrypted ? Icons.lock : Icons.code,
                size: 14,
                color: envVar.isEncrypted
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                envVar.isEncrypted ? 'Encrypted' : 'Visible',
                style: TextStyle(
                  fontSize: 11,
                  color: envVar.isEncrypted
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
