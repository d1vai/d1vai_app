import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/database_table.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';
import '../table_detail_dialog.dart';

/// 项目详情页 - Database Tab
class ProjectDatabaseTab extends StatefulWidget {
  final UserProject project;
  final void Function(String prompt)? onAskAi;
  final Future<void> Function()? onRefreshProject;

  const ProjectDatabaseTab({
    super.key,
    required this.project,
    this.onAskAi,
    this.onRefreshProject,
  });

  @override
  State<ProjectDatabaseTab> createState() => _ProjectDatabaseTabState();
}

class _ProjectDatabaseTabState extends State<ProjectDatabaseTab> {
  final List<DatabaseTable> _tables = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _enabling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      if (_hasDatabaseEnabled) {
        _loadTables();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProjectDatabaseTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enabledChanged =
        oldWidget.project.projectDatabaseId != widget.project.projectDatabaseId;
    if (enabledChanged && _hasDatabaseEnabled) {
      _loadTables();
    }
    if (oldWidget.project.id != widget.project.id && _hasDatabaseEnabled) {
      _loadTables();
    }
  }

  bool get _hasDatabaseEnabled =>
      widget.project.projectDatabaseId != null &&
      widget.project.projectDatabaseId! > 0;

  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = D1vaiService();
      final schemaData = await service.getProjectDbSchema(
        widget.project.id,
        withRowCounts: true,
        includeViews: true,
      );

      final List<DatabaseTable> tables = [];
      if (schemaData['schemas'] != null) {
        for (final schema in schemaData['schemas']) {
          if (schema['tables'] != null) {
            for (final table in schema['tables']) {
              tables.add(DatabaseTable.fromJson(table));
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _tables
          ..clear()
          ..addAll(tables);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final msg = humanizeError(e);
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

  Future<void> _enableDatabase() async {
    if (_enabling) return;
    setState(() {
      _enabling = true;
    });

    try {
      final service = D1vaiService();
      await service.activateProjectDatabase(widget.project.id);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Database enabled successfully!',
      );
      await widget.onRefreshProject?.call();
      if (!mounted) return;
      if (_hasDatabaseEnabled) {
        await _loadTables();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
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
    } finally {
      if (mounted) {
        setState(() {
          _enabling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasDatabaseEnabled) {
      return _EnableDatabaseCard(
        enabling: _enabling,
        onEnable: _enableDatabase,
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No database tables',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Database tables will appear here once they are created',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = _tables[index];
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: table.type == 'view'
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                table.type == 'view' ? Icons.visibility : Icons.table_chart,
                color: table.type == 'view'
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              table.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${table.columns.length} columns • ${table.schema} schema',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (table.rowCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${table.rowCount} rows',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final question =
                  'Can you analyze the database table "${table.displayName}" and explain its purpose, structure, and any suggestions for optimization or best practices?';
              widget.onAskAi?.call(question);
            },
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => TableDetailDialog(table: table),
              );
            },
          ),
        );
      },
    );
  }
}

class _EnableDatabaseCard extends StatelessWidget {
  final bool enabling;
  final VoidCallback onEnable;

  const _EnableDatabaseCard({
    required this.enabling,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storage,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enable Database',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provision a Neon PostgreSQL database for this project and start exploring your schema and data.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.cloud_outlined,
                    text: 'Serverless Postgres on Neon',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.lock_outline,
                    text: 'Secure SSL connections',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.alt_route_outlined,
                    text: 'Branching support',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: enabling ? null : onEnable,
                      icon: enabling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt),
                      label: Text(enabling ? 'Enabling...' : 'Enable Database'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
