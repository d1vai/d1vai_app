import 'package:flutter/material.dart';

import '../../models/database_table.dart';
import '../../services/d1vai_service.dart';
import '../snackbar_helper.dart';
import '../table_detail_dialog.dart';

/// 项目详情页 - Database Tab
class ProjectDatabaseTab extends StatefulWidget {
  final String projectId;
  final void Function(String prompt)? onAskAi;

  const ProjectDatabaseTab({
    super.key,
    required this.projectId,
    this.onAskAi,
  });

  @override
  State<ProjectDatabaseTab> createState() => _ProjectDatabaseTabState();
}

class _ProjectDatabaseTabState extends State<ProjectDatabaseTab> {
  final List<DatabaseTable> _tables = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadTables();
    }
  }

  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = D1vaiService();
      final schemaData = await service.getProjectDbSchema(
        widget.projectId,
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
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to load database tables',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
