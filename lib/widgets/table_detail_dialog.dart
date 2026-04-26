import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/database_table.dart';
import '../services/d1vai_service.dart';
import 'adaptive_modal.dart';

/// 数据库表详情对话框
class TableDetailDialog extends StatefulWidget {
  final DatabaseTable table;
  final String? projectId;
  final String? branch;

  const TableDetailDialog({
    super.key,
    required this.table,
    this.projectId,
    this.branch,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required DatabaseTable table,
    String? projectId,
    String? branch,
  }) {
    return showAdaptiveModal<T>(
      context: context,
      builder: (context) =>
          TableDetailDialog(table: table, projectId: projectId, branch: branch),
    );
  }

  @override
  State<TableDetailDialog> createState() => _TableDetailDialogState();
}

class _TableDetailDialogState extends State<TableDetailDialog> {
  final D1vaiService _service = D1vaiService();
  int _currentTab = 0;
  List<Map<String, dynamic>> _sampleRows = const <Map<String, dynamic>>[];
  bool _isLoadingRows = false;
  String? _rowsError;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadSampleRows();
  }

  Future<void> _loadSampleRows() async {
    final projectId = (widget.projectId ?? '').trim();
    if (projectId.isEmpty) return;
    setState(() {
      _isLoadingRows = true;
      _rowsError = null;
    });
    try {
      final rows = await _service.listDbRows(
        projectId,
        widget.table.schema,
        widget.table.name,
        branch: widget.branch,
        limit: 10,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _sampleRows = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        _isLoadingRows = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rowsError = '$e';
        _isLoadingRows = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = widget.table;

    return AdaptiveModalContainer(
      maxWidth: 920,
      mobileMaxHeightFactor: 0.98,
      desktopMaxHeightFactor: 0.92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveModalHeader(
            title: table.displayName,
            subtitle: '${table.schema} schema • ${table.type}',
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: table.type == 'view'
                    ? Colors.orange.withValues(alpha: 0.14)
                    : Colors.blue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                table.type == 'view' ? Icons.visibility : Icons.table_chart,
                color: table.type == 'view' ? Colors.orange : Colors.blue,
              ),
            ),
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton(0, 'Schema')),
                  Expanded(child: _buildTabButton(1, 'Sample Data')),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: IndexedStack(
                index: _currentTab,
                children: [_buildSchemaTab(), _buildDataTab()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSchemaTab() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.table.type == 'view'
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.table.type == 'view'
                        ? Icons.visibility
                        : Icons.table_chart,
                    color: widget.table.type == 'view'
                        ? Colors.orange
                        : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        label: '${widget.table.columns.length} columns',
                        icon: Icons.view_column,
                      ),
                      if (widget.table.rowCount != null)
                        _StatChip(
                          label: '${widget.table.rowCount} rows',
                          icon: Icons.dataset,
                        ),
                      _StatChip(
                        label: widget.table.type ?? 'table',
                        icon: Icons.label_outline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Columns',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.table.columns.length,
              separatorBuilder: (context, index) => Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              itemBuilder: (context, index) {
                final columnName = widget.table.columns[index];
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        columnName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Unknown',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTab() {
    final theme = Theme.of(context);
    final columns = widget.table.columns;
    final projectId = (widget.projectId ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sample data preview - showing up to 10 rows',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: _t('project_database_refresh_rows', 'Refresh rows'),
                  onPressed: (projectId.isEmpty || _isLoadingRows)
                      ? null
                      : _loadSampleRows,
                  icon: _isLoadingRows
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: _isLoadingRows
                ? const Center(child: CircularProgressIndicator())
                : columns.isEmpty
                ? _buildEmptyState(
                    icon: Icons.view_column_outlined,
                    title: _t(
                      'project_database_no_columns',
                      'No visible columns',
                    ),
                    subtitle: _t(
                      'project_database_no_columns_hint',
                      'This table currently has no browsable columns.',
                    ),
                  )
                : _rowsError != null && _rowsError!.trim().isNotEmpty
                ? _buildEmptyState(
                    icon: Icons.error_outline,
                    title: _t('error', 'Error'),
                    subtitle: _rowsError!,
                  )
                : _sampleRows.isEmpty
                ? _buildEmptyState(
                    icon: Icons.inbox_outlined,
                    title: _t('project_database_no_rows', 'No rows found'),
                    subtitle: _t(
                      'project_database_no_rows_hint',
                      'Try another table or insert data from your application flow.',
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          columns: columns
                              .map((col) => DataColumn(label: Text(col)))
                              .toList(),
                          rows: _sampleRows
                              .map(
                                (row) => DataRow(
                                  cells: columns
                                      .map(
                                        (col) => DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 240,
                                            ),
                                            child: Text(
                                              _formatCellValue(row[col]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is Map || value is List) return value.toString();
    final text = value.toString();
    return text.isEmpty ? '""' : text;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
