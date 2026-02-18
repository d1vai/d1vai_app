import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/database_table.dart';
import '../../models/project.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';
import '../table_detail_dialog.dart';
import '../../widgets/select.dart';
import 'package:d1vai_app/widgets/skeletons/project_database_skeleton.dart';

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
  final D1vaiService _service = D1vaiService();
  final List<DatabaseTable> _tables = [];
  final Map<String, _DbTableMeta> _tableMetaByKey = {};
  final List<Map<String, dynamic>> _rows = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _enabling = false;
  bool _isLoadingBranches = false;
  bool _isLoadingRows = false;
  bool _isRefreshingRows = false;
  bool _isMutatingRows = false;
  bool _isLoadingMigrations = false;
  bool _hasNextRowsPage = false;
  int _rowsPageSize = 50;
  int _rowsPageIndex = 0;
  String _selectedTableKey = '';
  final List<_DbMigrationPlan> _migrationPlans = [];
  _DbPrimaryTab _activeTab = _DbPrimaryTab.schema;
  _DbViewMode _viewMode = _DbViewMode.tables;
  final List<_DbBranchItem> _branches = [];
  String _selectedBranch = '';
  bool _showActivationGuide = false;

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
      if (_hasDatabaseEnabled) {
        unawaited(_bootstrapDatabaseView());
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProjectDatabaseTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enabledChanged =
        oldWidget.project.hasDatabaseEnabled !=
        widget.project.hasDatabaseEnabled;
    if (enabledChanged && _hasDatabaseEnabled) {
      unawaited(_bootstrapDatabaseView());
    }
    if (oldWidget.project.id != widget.project.id) {
      _tables.clear();
      _tableMetaByKey.clear();
      _rows.clear();
      _migrationPlans.clear();
      _branches.clear();
      _selectedBranch = '';
      _selectedTableKey = '';
      _rowsPageIndex = 0;
      _hasNextRowsPage = false;
      _activeTab = _DbPrimaryTab.schema;
      _viewMode = _DbViewMode.tables;
      if (_hasDatabaseEnabled) {
        unawaited(_bootstrapDatabaseView());
      }
    }
  }

  bool get _hasDatabaseEnabled => widget.project.hasDatabaseEnabled;

  _DbTableMeta? get _selectedTableMeta {
    if (_selectedTableKey.trim().isEmpty) return null;
    return _tableMetaByKey[_selectedTableKey];
  }

  Future<void> _bootstrapDatabaseView() async {
    setState(() {
      _isLoading = true;
      _showActivationGuide = false;
    });

    await _loadBranches();
    if (_showActivationGuide) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    await _refreshActiveTab();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final branchData = await _service.getProjectDbBranches(widget.project.id);
      final branches = <_DbBranchItem>[];
      for (final b in branchData) {
        if (b is! Map) continue;
        final map = Map<String, dynamic>.from(b);
        final id = (map['id'] ?? '').toString().trim();
        final name = (map['name'] ?? id).toString().trim();
        if (name.isEmpty) continue;
        branches.add(
          _DbBranchItem(
            id: id.isEmpty ? name : id,
            name: name,
            primary: map['primary'] == true,
          ),
        );
      }
      final fallback = branches.isNotEmpty
          ? branches
          : const [_DbBranchItem(id: 'main', name: 'main', primary: true)];
      final primary = fallback.firstWhere(
        (e) => e.primary,
        orElse: () => fallback.first,
      );
      final keepCurrent =
          _selectedBranch.isNotEmpty &&
          fallback.any((e) => e.name == _selectedBranch);
      if (!mounted) return;
      setState(() {
        _branches
          ..clear()
          ..addAll(fallback);
        _selectedBranch = keepCurrent ? _selectedBranch : primary.name;
        _isLoadingBranches = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBranches = false;
        if (_selectedBranch.isEmpty) {
          _selectedBranch = 'main';
        }
      });
      final msg = humanizeError(e);
      if (msg.contains('404') || msg.toLowerCase().contains('not found')) {
        if (mounted) {
          setState(() {
            _showActivationGuide = true;
            _isLoadingBranches = false;
          });
        }
        return;
      }
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/db/branches',
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

  Future<void> _loadTables() async {
    try {
      final schemaData = await _service.getProjectDbSchema(
        widget.project.id,
        branch: _selectedBranch.trim().isEmpty ? null : _selectedBranch.trim(),
        withRowCounts: true,
        includeViews: true,
      );

      final rawTables = _extractSchemaTables(schemaData);
      final metaByKey = <String, _DbTableMeta>{};
      for (final raw in rawTables) {
        final meta = _DbTableMeta.fromJson(raw);
        metaByKey[meta.fullName] = meta;
      }
      final tables =
          metaByKey.values
              .map((meta) => meta.toDatabaseTable())
              .toList(growable: false)
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
      final selectedKey = _resolveSelectedTableKey(metaByKey.keys);

      if (!mounted) return;

      setState(() {
        _tables
          ..clear()
          ..addAll(tables);
        _tableMetaByKey
          ..clear()
          ..addAll(metaByKey);
        _selectedTableKey = selectedKey;
        _isLoading = false;
      });

      if (_activeTab == _DbPrimaryTab.data &&
          _selectedTableMeta != null &&
          mounted) {
        await _loadRows(isRefresh: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final msg = humanizeError(e);
      if (msg.contains('404') || msg.toLowerCase().contains('not found')) {
        if (mounted) {
          setState(() {
            _showActivationGuide = true;
            _isLoading = false;
          });
        }
        return;
      }
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/db/schema',
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

  List<Map<String, dynamic>> _extractSchemaTables(Map<String, dynamic> schema) {
    final out = <Map<String, dynamic>>[];
    final rawTables = schema['tables'];
    if (rawTables is List) {
      for (final t in rawTables) {
        if (t is Map<String, dynamic>) {
          out.add(t);
        } else if (t is Map) {
          out.add(Map<String, dynamic>.from(t));
        }
      }
      return out;
    }

    final schemas = schema['schemas'];
    if (schemas is List) {
      for (final schemaEntry in schemas) {
        if (schemaEntry is! Map) continue;
        final schemaMap = Map<String, dynamic>.from(schemaEntry);
        final st = schemaMap['tables'];
        if (st is! List) continue;
        final schemaName =
            (schemaMap['schema_name'] ?? schemaMap['name'] ?? 'public')
                .toString();
        for (final table in st) {
          if (table is! Map) continue;
          final row = Map<String, dynamic>.from(table);
          row.putIfAbsent('schema', () => schemaName);
          row.putIfAbsent('schema_name', () => schemaName);
          out.add(row);
        }
      }
    }
    return out;
  }

  String _resolveSelectedTableKey(Iterable<String> available) {
    if (available.isEmpty) return '';
    if (_selectedTableKey.isNotEmpty && available.contains(_selectedTableKey)) {
      return _selectedTableKey;
    }
    return available.first;
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
        title: _t('success', 'Success'),
        message: _t(
          'project_database_enabled_success',
          'Database enabled successfully!',
        ),
      );
      await widget.onRefreshProject?.call();
      if (!mounted) return;
      if (_hasDatabaseEnabled) {
        setState(() {
          _activeTab = _DbPrimaryTab.schema;
        });
        await _bootstrapDatabaseView();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint:
              '/api/projects/${widget.project.id}/integrations/activate-database',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: msg,
      );
    } finally {
      if (mounted) {
        setState(() {
          _enabling = false;
        });
      }
    }
  }

  Future<void> _loadRows({required bool isRefresh}) async {
    final selected = _selectedTableMeta;
    if (selected == null) {
      setState(() {
        _rows.clear();
        _hasNextRowsPage = false;
      });
      return;
    }

    setState(() {
      if (isRefresh) {
        _isRefreshingRows = true;
      } else {
        _isLoadingRows = true;
      }
    });

    try {
      final data = await _service.listDbRows(
        widget.project.id,
        selected.schema,
        selected.name,
        branch: _selectedBranch.trim().isEmpty ? null : _selectedBranch.trim(),
        limit: _rowsPageSize,
        offset: _rowsPageIndex * _rowsPageSize,
      );
      final rows = <Map<String, dynamic>>[];
      for (final row in data) {
        if (row is Map<String, dynamic>) {
          rows.add(row);
        } else if (row is Map) {
          rows.add(Map<String, dynamic>.from(row));
        }
      }

      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(rows);
        _hasNextRowsPage = rows.length >= _rowsPageSize;
        _isLoadingRows = false;
        _isRefreshingRows = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRows = false;
        _isRefreshingRows = false;
      });
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint:
              '/api/projects/${widget.project.id}/db/tables/${selected.schema}/${selected.name}/rows',
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

  Future<void> _openTableInData(_DbTableMeta table) async {
    setState(() {
      _selectedTableKey = table.fullName;
      _rowsPageIndex = 0;
      _activeTab = _DbPrimaryTab.data;
    });
    await _loadRows(isRefresh: false);
  }

  Future<void> _onSelectTableInData(String key) async {
    if (_selectedTableKey == key) return;
    setState(() {
      _selectedTableKey = key;
      _rowsPageIndex = 0;
    });
    await _loadRows(isRefresh: false);
  }

  Future<void> _onRowsPageSizeChanged(int next) async {
    if (next == _rowsPageSize) return;
    setState(() {
      _rowsPageSize = next;
      _rowsPageIndex = 0;
    });
    await _loadRows(isRefresh: false);
  }

  Future<void> _goPrevRowsPage() async {
    if (_rowsPageIndex <= 0) return;
    setState(() {
      _rowsPageIndex -= 1;
    });
    await _loadRows(isRefresh: false);
  }

  Future<void> _goNextRowsPage() async {
    if (!_hasNextRowsPage) return;
    setState(() {
      _rowsPageIndex += 1;
    });
    await _loadRows(isRefresh: false);
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      return value.isEmpty ? '""' : value;
    }
    if (value is num || value is bool) return value.toString();
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  dynamic _coerceInputValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase() == 'null') return null;
    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
    return raw;
  }

  Map<String, dynamic> _buildRowWhere(
    _DbTableMeta table,
    Map<String, dynamic> row,
  ) {
    final where = <String, dynamic>{};
    final pkNames = table.columns
        .where((col) => col.isPrimaryKey)
        .map((col) => col.name)
        .toList(growable: false);
    final targetCols = pkNames.isNotEmpty
        ? pkNames
        : table.columns.map((col) => col.name).toList(growable: false);
    for (final col in targetCols) {
      where[col] = row[col];
    }
    return where;
  }

  Future<void> _openRowEditor(
    _DbTableMeta table, {
    required bool isInsert,
    Map<String, dynamic>? sourceRow,
  }) async {
    final editable = table.columns
        .where((col) => !col.isPrimaryKey)
        .toList(growable: false);
    if (editable.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: _t(
          'project_database_no_editable_columns',
          'No editable columns',
        ),
        message: _t(
          'project_database_no_editable_columns_hint',
          'This table has no editable non-primary-key columns.',
        ),
      );
      return;
    }

    final controllers = <String, TextEditingController>{
      for (final col in editable)
        col.name: TextEditingController(
          text: sourceRow == null ? '' : _formatCellValue(sourceRow[col.name]),
        ),
    };
    var submitting = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isInsert
                    ? _t('project_database_insert_row', 'Insert row')
                    : _t('project_database_edit_row', 'Edit row'),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: editable.map((col) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: controllers[col.name],
                          decoration: InputDecoration(
                            labelText: col.name,
                            helperText: col.dataType.isEmpty
                                ? null
                                : col.isNullable
                                ? col.dataType
                                : '${col.dataType}${_t('project_database_required_suffix', ' • required')}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('cancel', 'Cancel')),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                          });
                          setState(() {
                            _isMutatingRows = true;
                          });
                          try {
                            final values = <String, dynamic>{};
                            for (final col in editable) {
                              final raw = controllers[col.name]?.text ?? '';
                              values[col.name] = _coerceInputValue(raw);
                            }

                            if (isInsert) {
                              await _service.insertDbRow(
                                widget.project.id,
                                table.schema,
                                table.name,
                                branch: _selectedBranch.trim().isEmpty
                                    ? null
                                    : _selectedBranch.trim(),
                                values: values,
                              );
                            } else {
                              if (sourceRow == null) return;
                              await _service.updateDbRows(
                                widget.project.id,
                                table.schema,
                                table.name,
                                branch: _selectedBranch.trim().isEmpty
                                    ? null
                                    : _selectedBranch.trim(),
                                where: _buildRowWhere(table, sourceRow),
                                values: values,
                              );
                            }
                            if (!mounted) return;
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } catch (e) {
                            if (!mounted) return;
                            final msg = humanizeError(e);
                            if (isAuthExpiredText(msg)) {
                              AuthExpiryBus.trigger(
                                endpoint:
                                    '/api/projects/${widget.project.id}/db/tables/${table.schema}/${table.name}/rows',
                              );
                              return;
                            }
                            SnackBarHelper.showError(
                              this.context,
                              title: _t('error', 'Error'),
                              message: msg,
                            );
                            setDialogState(() {
                              submitting = false;
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isMutatingRows = false;
                              });
                            }
                          }
                        },
                  child: Text(
                    submitting
                        ? (isInsert
                              ? _t('project_database_inserting', 'Inserting...')
                              : _t('project_database_saving', 'Saving...'))
                        : (isInsert
                              ? _t('project_database_insert', 'Insert')
                              : _t('save', 'Save')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    if (ok == true && mounted) {
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: isInsert
            ? _t('project_database_row_inserted', 'Row inserted.')
            : _t('project_database_row_updated', 'Row updated.'),
      );
      await _loadRows(isRefresh: true);
    }
  }

  Future<void> _deleteRow(_DbTableMeta table, Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('project_database_delete_row', 'Delete row')),
          content: Text(
            _t(
              'project_database_delete_row_confirm',
              'Delete this row from {table}? This action cannot be undone.',
            ).replaceAll('{table}', table.fullName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('cancel', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_t('delete', 'Delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isMutatingRows = true;
    });
    try {
      await _service.deleteDbRows(
        widget.project.id,
        table.schema,
        table.name,
        branch: _selectedBranch.trim().isEmpty ? null : _selectedBranch.trim(),
        where: _buildRowWhere(table, row),
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: _t('project_database_row_deleted', 'Row deleted.'),
      );
      await _loadRows(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint:
              '/api/projects/${widget.project.id}/db/tables/${table.schema}/${table.name}/rows/delete',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: msg,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingRows = false;
        });
      }
    }
  }

  Future<void> _loadMigrationHistory() async {
    setState(() {
      _isLoadingMigrations = true;
    });
    try {
      final data = await _service.getProjectMigrationHistory(
        widget.project.id,
        limit: 50,
        offset: 0,
      );
      dynamic rawPlans = data['plans'];
      if (rawPlans is! List && data['data'] is Map) {
        rawPlans = (data['data'] as Map)['plans'];
      }
      if (rawPlans is! List && data['data'] is List) {
        rawPlans = data['data'];
      }
      final plans = <_DbMigrationPlan>[];
      if (rawPlans is List) {
        for (final item in rawPlans) {
          if (item is Map<String, dynamic>) {
            plans.add(_DbMigrationPlan.fromJson(item));
          } else if (item is Map) {
            plans.add(
              _DbMigrationPlan.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _migrationPlans
          ..clear()
          ..addAll(plans);
        _isLoadingMigrations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMigrations = false;
      });
      final msg = humanizeError(e);
      if (isAuthExpiredText(msg)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/migrations/history/${widget.project.id}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasDatabaseEnabled || _showActivationGuide) {
      return _EnableDatabaseCard(
        enabling: _enabling,
        onEnable: _enableDatabase,
      );
    }

    if (_isLoading) {
      return const ProjectDatabaseSkeleton();
    }

    return Column(
      children: [
        _buildDatabaseTopBar(theme),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: const SizedBox.shrink(), // Hints removed
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: switch (_activeTab) {
              _DbPrimaryTab.schema => _buildSchemaTab(theme),
              _DbPrimaryTab.data => _buildDataTab(theme),
              _DbPrimaryTab.migration => _buildMigrationTab(theme),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseTopBar(ThemeData theme) {
    final selected = _selectedBranch.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_DbPrimaryTab>(
                  segments: [
                    ButtonSegment(
                      value: _DbPrimaryTab.schema,
                      icon: Icon(Icons.account_tree_outlined),
                      label: Text(_t('project_database_tab_schema', 'Schema')),
                    ),
                    ButtonSegment(
                      value: _DbPrimaryTab.data,
                      icon: Icon(Icons.table_view_outlined),
                      label: Text(_t('project_database_tab_data', 'Data')),
                    ),
                    ButtonSegment(
                      value: _DbPrimaryTab.migration,
                      icon: Icon(Icons.history_toggle_off),
                      label: Text(
                        _t('project_database_tab_migration', 'Migration'),
                      ),
                    ),
                  ],
                  selected: <_DbPrimaryTab>{_activeTab},
                  onSelectionChanged: (set) =>
                      _handleActiveTabChanged(set.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Select<String>(
                  value: selected.isEmpty ? null : selected,
                  label: _t('project_database_branch', 'Branch'),
                  hint: Text(
                    _isLoadingBranches
                        ? _t(
                            'project_database_loading_branches',
                            'Loading branches...',
                          )
                        : _t(
                            'project_database_branch_hint',
                            'Current Neon branch context',
                          ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  items: _branches
                      .map(
                        (b) => SelectItem<String>(
                          value: b.name,
                          child: Text(
                            b.primary
                                ? _t(
                                    'project_database_branch_primary',
                                    '{name} (primary)',
                                  ).replaceAll('{name}', b.name)
                                : b.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoadingBranches
                      ? null
                      : (value) {
                          if (value == null) return;
                          unawaited(_handleBranchChanged(value));
                        },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _t('refresh', 'Refresh'),
                onPressed: () => unawaited(_refreshActiveTab()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaTab(ThemeData theme) {
    if (_tables.isEmpty) {
      return _buildEmptyState(
        icon: Icons.storage,
        title: _t('project_database_no_tables', 'No database tables'),
        subtitle: _t(
          'project_database_no_tables_hint',
          'Database tables will appear here once they are created.',
        ),
      );
    }
    return Column(
      key: const ValueKey('db_schema'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<_DbViewMode>(
            segments: [
              ButtonSegment(
                value: _DbViewMode.tables,
                icon: Icon(Icons.table_chart),
                label: Text(_t('project_database_view_tables', 'Tables')),
              ),
              ButtonSegment(
                value: _DbViewMode.relations,
                icon: Icon(Icons.account_tree),
                label: Text(_t('project_database_view_relations', 'Relations')),
              ),
              ButtonSegment(
                value: _DbViewMode.graph,
                icon: Icon(Icons.hub),
                label: Text(_t('project_database_view_graph', 'Graph')),
              ),
            ],
            selected: <_DbViewMode>{_viewMode},
            onSelectionChanged: (set) {
              setState(() {
                _viewMode = set.first;
              });
            },
          ),
        ),
        Expanded(
          child: switch (_viewMode) {
            _DbViewMode.tables => _buildTablesList(theme),
            _DbViewMode.relations => _buildRelationsList(theme),
            _DbViewMode.graph => _buildGraphView(theme),
          },
        ),
      ],
    );
  }

  Widget _buildDataTab(ThemeData theme) {
    if (_tables.isEmpty || _tableMetaByKey.isEmpty) {
      return _buildEmptyState(
        key: const ValueKey('db_data_empty'),
        icon: Icons.table_view,
        title: _t('project_database_no_tables', 'No database tables'),
        subtitle: _t(
          'project_database_data_empty_hint',
          'Create tables first, then browse rows here.',
        ),
      );
    }

    final options = _tableMetaByKey.values.toList(growable: false)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final selected = _selectedTableMeta ?? options.first;
    final hasEditableColumns = selected.columns.any((col) => !col.isPrimaryKey);
    final canMutateRows = !selected.isView && hasEditableColumns;

    return Padding(
      key: const ValueKey('db_data_ready'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Select<String>(
                          value: selected.fullName,
                          label: _t('project_database_table', 'Table'),
                          hint: Text(
                            _t('project_database_select_table', 'Select Table'),
                          ),
                          isDense: true,
                          items: options
                              .map(
                                (meta) => SelectItem<String>(
                                  value: meta.fullName,
                                  child: Text(
                                    meta.isView
                                        ? _t(
                                            'project_database_table_view',
                                            '{name} (view)',
                                          ).replaceAll('{name}', meta.fullName)
                                        : meta.fullName,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            unawaited(_onSelectTableInData(value));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                tooltip: _t(
                                  'project_database_refresh_rows',
                                  'Refresh rows',
                                ),
                                onPressed:
                                    (_isLoadingRows ||
                                        _isRefreshingRows ||
                                        _isMutatingRows)
                                    ? null
                                    : () =>
                                          unawaited(_loadRows(isRefresh: true)),
                                icon: _isRefreshingRows
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 20),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed:
                                    (_isMutatingRows ||
                                        _isLoadingRows ||
                                        !canMutateRows)
                                    ? null
                                    : () => unawaited(
                                        _openRowEditor(
                                          selected,
                                          isInsert: true,
                                        ),
                                      ),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  _t('project_database_insert', 'Insert'),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _t(
                            'project_database_columns_schema',
                            '{columns} columns • {schema} schema',
                          )
                          .replaceAll(
                            '{columns}',
                            selected.columns.length.toString(),
                          )
                          .replaceAll('{schema}', selected.schema),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoadingRows
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                    ? _buildEmptyState(
                        key: const ValueKey('db_data_no_rows'),
                        icon: Icons.inbox_outlined,
                        title: _t('project_database_no_rows', 'No rows found'),
                        subtitle: _t(
                          'project_database_no_rows_hint',
                          'Try another table or insert data from your application flow.',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(1),
                        child: _buildRowsTable(theme, selected),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _t(
                  'project_database_page',
                  'Page {index}',
                ).replaceAll('{index}', (_rowsPageIndex + 1).toString()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: _rowsPageSize,
                items: const [20, 50, 100]
                    .map(
                      (size) => DropdownMenuItem<int>(
                        value: size,
                        child: Text(
                          _t(
                            'project_database_page_size',
                            '{size} / page',
                          ).replaceAll('{size}', size.toString()),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  unawaited(_onRowsPageSizeChanged(value));
                },
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: (_rowsPageIndex > 0 && !_isMutatingRows)
                    ? () => unawaited(_goPrevRowsPage())
                    : null,
                child: Text(_t('project_database_previous', 'Previous')),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: (_hasNextRowsPage && !_isMutatingRows)
                    ? () => unawaited(_goNextRowsPage())
                    : null,
                child: Text(_t('project_database_next', 'Next')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowsTable(ThemeData theme, _DbTableMeta selected) {
    if (selected.columns.isEmpty) {
      return _buildEmptyState(
        key: const ValueKey('db_data_no_columns'),
        icon: Icons.view_column_outlined,
        title: _t('project_database_no_columns', 'No visible columns'),
        subtitle: _t(
          'project_database_no_columns_hint',
          'This table currently has no browsable columns.',
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: [
              ...selected.columns.map(
                (col) => DataColumn(
                  label: Text(
                    col.isPrimaryKey
                        ? _t(
                            'project_database_column_pk',
                            '{name} (PK)',
                          ).replaceAll('{name}', col.name)
                        : col.name,
                  ),
                  tooltip: col.dataType,
                ),
              ),
              DataColumn(
                label: Text(_t('project_database_actions', 'Actions')),
              ),
            ],
            rows: _rows
                .map(
                  (row) => DataRow(
                    cells: [
                      ...selected.columns.map(
                        (col) => DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              _formatCellValue(row[col.name]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _t(
                                'project_database_edit_row',
                                'Edit row',
                              ),
                              onPressed: (_isMutatingRows || selected.isView)
                                  ? null
                                  : () => unawaited(
                                      _openRowEditor(
                                        selected,
                                        isInsert: false,
                                        sourceRow: row,
                                      ),
                                    ),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: _t(
                                'project_database_delete_row',
                                'Delete row',
                              ),
                              onPressed: (_isMutatingRows || selected.isView)
                                  ? null
                                  : () => unawaited(_deleteRow(selected, row)),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMigrationTab(ThemeData theme) {
    if (_isLoadingMigrations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_migrationPlans.isEmpty) {
      return _buildEmptyState(
        key: const ValueKey('db_migration_empty'),
        icon: Icons.history,
        title: _t('project_database_no_migration', 'No migration history'),
        subtitle: _t(
          'project_database_no_migration_hint',
          'Migration plans and execution records will appear here.',
        ),
      );
    }

    return Padding(
      key: const ValueKey('db_migration_ready'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t(
                    'project_database_migration_plans',
                    '{count} plans',
                  ).replaceAll('{count}', _migrationPlans.length.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoadingMigrations
                    ? null
                    : () => unawaited(_loadMigrationHistory()),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(_t('refresh', 'Refresh')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _migrationPlans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = _migrationPlans[index];
                return Card(
                  child: ExpansionTile(
                    leading: Icon(
                      _migrationStatusIcon(plan.status),
                      color: _migrationStatusColor(theme, plan.status),
                    ),
                    title: Text(
                      plan.intent.isEmpty
                          ? _t(
                              'project_database_migration_plan',
                              'Migration plan',
                            )
                          : plan.intent,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _t(
                            'project_database_migration_job_count',
                            '{time} • {count} jobs',
                          )
                          .replaceAll('{time}', _formatDateTime(plan.createdAt))
                          .replaceAll('{count}', plan.jobCount.toString()),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _migrationStatusColor(
                          theme,
                          plan.status,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        plan.status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _migrationStatusColor(theme, plan.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    children: [
                      if (plan.jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _t(
                                'project_database_no_job_details',
                                'No job details available yet.',
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ...plan.jobs.map((job) {
                          return ListTile(
                            leading: Icon(
                              _migrationStatusIcon(job.status),
                              color: _migrationStatusColor(theme, job.status),
                              size: 18,
                            ),
                            title: Text(
                              '${job.stage.toUpperCase()} • ${job.status}',
                            ),
                            subtitle: Text(
                              _t(
                                    'project_database_statement_count',
                                    '{time} • {count} statements',
                                  )
                                  .replaceAll(
                                    '{time}',
                                    _formatDateTime(job.createdAt),
                                  )
                                  .replaceAll(
                                    '{count}',
                                    (job.statementCount ?? 0).toString(),
                                  ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _migrationStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      case 'partial':
        return Icons.warning_amber_outlined;
      default:
        return Icons.schedule;
    }
  }

  Color _migrationStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green.shade600;
      case 'failed':
        return theme.colorScheme.error;
      case 'partial':
        return Colors.orange.shade700;
      default:
        return theme.colorScheme.tertiary;
    }
  }

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMd(localeTag).add_Hm().format(local);
  }

  Widget _buildEmptyState({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleActiveTabChanged(_DbPrimaryTab next) {
    if (_activeTab == next) return;
    setState(() {
      _activeTab = next;
      if (next == _DbPrimaryTab.data) {
        _rowsPageIndex = 0;
        if (_selectedTableKey.isEmpty && _tableMetaByKey.isNotEmpty) {
          _selectedTableKey = _tableMetaByKey.keys.first;
        }
      }
    });
    if (next == _DbPrimaryTab.data) {
      unawaited(_loadRows(isRefresh: false));
    }
    if (next == _DbPrimaryTab.migration && _migrationPlans.isEmpty) {
      unawaited(_loadMigrationHistory());
    }
  }

  Future<void> _handleBranchChanged(String branchName) async {
    if (branchName == _selectedBranch) return;
    setState(() {
      _selectedBranch = branchName;
      _rowsPageIndex = 0;
    });
    await _refreshActiveTab();
  }

  Future<void> _refreshActiveTab() async {
    switch (_activeTab) {
      case _DbPrimaryTab.schema:
        await _loadTables();
        break;
      case _DbPrimaryTab.data:
        await _loadTables();
        break;
      case _DbPrimaryTab.migration:
        await _loadMigrationHistory();
        break;
    }
  }

  Widget _buildTablesList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = _tables[index];
        IconData tableIcon;
        final name = table.displayName.toLowerCase();
        if (name.contains('user') ||
            name.contains('account') ||
            name.contains('profile')) {
          tableIcon = Icons.person_outline;
        } else if (name.contains('order') ||
            name.contains('transaction') ||
            name.contains('payment') ||
            name.contains('bill')) {
          tableIcon = Icons.receipt_long;
        } else if (name.contains('product') ||
            name.contains('item') ||
            name.contains('sku')) {
          tableIcon = Icons.inventory_2_outlined;
        } else if (name.contains('msg') ||
            name.contains('message') ||
            name.contains('chat')) {
          tableIcon = Icons.chat_bubble_outline;
        } else if (name.contains('log') ||
            name.contains('history') ||
            name.contains('audit')) {
          tableIcon = Icons.history;
        } else if (name.contains('auth') ||
            name.contains('verify') ||
            name.contains('token') ||
            name.contains('session')) {
          tableIcon = Icons.verified_user_outlined;
        } else if (name.contains('setting') || name.contains('config')) {
          tableIcon = Icons.settings_outlined;
        } else {
          tableIcon = Icons.table_chart_outlined;
        }

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: table.type == 'view'
                    ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                table.type == 'view' ? Icons.visibility : tableIcon,
                color: table.type == 'view'
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
                size: 24,
              ),
            ),
            title: Text(
              table.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _t(
                        'project_database_columns_schema',
                        '{columns} columns • {schema} schema',
                      )
                      .replaceAll('{columns}', table.columns.length.toString())
                      .replaceAll('{schema}', table.schema),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (table.foreignKeys.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _t(
                      'project_database_relations_count',
                      '{count} relations',
                    ).replaceAll(
                      '{count}',
                      table.foreignKeys.length.toString(),
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (table.rowCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _t(
                      'project_database_rows_count',
                      '{count} rows',
                    ).replaceAll('{count}', table.rowCount.toString()),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _t(
                    'project_database_ask_ai_table',
                    'Ask AI about this table',
                  ),
                  onPressed: () {
                    final question = _t(
                      'project_database_ai_prompt_table',
                      'Can you analyze the database table "{table}" and explain its purpose, structure, and any suggestions for optimization or best practices?',
                    ).replaceAll('{table}', table.displayName);
                    widget.onAskAi?.call(question);
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () {
              final meta = _tableMetaByKey[table.fullName];
              if (meta == null) return;
              unawaited(_openTableInData(meta));
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

  Widget _buildRelationsList(ThemeData theme) {
    final withRelations =
        _tables.where((t) => t.foreignKeys.isNotEmpty).toList(growable: false)
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    if (withRelations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _t(
              'project_database_no_relations',
              'No foreign-key relationships found.',
            ),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: withRelations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = withRelations[index];
        return Card(
          child: ExpansionTile(
            title: Text(
              table.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _t(
                'project_database_relations_count',
                '{count} relations',
              ).replaceAll('{count}', table.foreignKeys.length.toString()),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            children: table.foreignKeys.map((fk) {
              return ListTile(
                leading: Icon(
                  Icons.call_split,
                  color: theme.colorScheme.tertiary,
                  size: 18,
                ),
                title: Text(
                  '${fk.columnName} → ${fk.refFullTable}.${fk.refColumn}',
                ),
                subtitle: fk.constraintName.trim().isEmpty
                    ? null
                    : Text(
                        fk.constraintName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                onTap: () {
                  widget.onAskAi?.call(
                    _t(
                          'project_database_ai_prompt_relation',
                          'Explain the relationship from {from} to {to}. Suggest indexes and common queries.',
                        )
                        .replaceAll(
                          '{from}',
                          '${table.fullName}.${fk.columnName}',
                        )
                        .replaceAll(
                          '{to}',
                          '${fk.refFullTable}.${fk.refColumn}',
                        ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildGraphView(ThemeData theme) {
    final tables = _tables.toList(growable: false)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    if (tables.length <= 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _t(
              'project_database_graph_hint',
              'Add more tables to see relationships as a graph.',
            ),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    const nodeSize = Size(168, 64);
    const gapX = 90.0;
    const gapY = 54.0;
    final cols = (tables.length <= 6) ? 2 : (tables.length <= 16 ? 3 : 4);

    final positions = <String, Offset>{};
    for (var i = 0; i < tables.length; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      positions[tables[i].fullName] = Offset(
        col * (nodeSize.width + gapX),
        row * (nodeSize.height + gapY),
      );
    }

    final maxRow = (tables.length - 1) ~/ cols;
    final canvasWidth = cols * nodeSize.width + (cols - 1) * gapX + 80;
    final canvasHeight = (maxRow + 1) * nodeSize.height + maxRow * gapY + 120;

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DbGraphPainter(
                  tables: tables,
                  positions: positions,
                  nodeSize: nodeSize,
                  colorScheme: theme.colorScheme,
                ),
              ),
            ),
            for (final t in tables)
              Positioned(
                left: (positions[t.fullName]?.dx ?? 0) + 30,
                top: (positions[t.fullName]?.dy ?? 0) + 30,
                child: _DbGraphNode(
                  table: t,
                  size: nodeSize,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => TableDetailDialog(table: t),
                    );
                  },
                  onLongPress: () {
                    final question = _t(
                      'project_database_ai_prompt_graph',
                      'Given the database schema, explain how "{table}" relates to other tables (foreign keys) and suggest improvements.',
                    ).replaceAll('{table}', t.fullName);
                    widget.onAskAi?.call(question);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DbTableMeta {
  final String schema;
  final String name;
  final String kind;
  final int? rowCount;
  final List<_DbColumnMeta> columns;
  final List<String> primaryKey;
  final List<DatabaseForeignKey> foreignKeys;

  const _DbTableMeta({
    required this.schema,
    required this.name,
    required this.kind,
    required this.rowCount,
    required this.columns,
    required this.primaryKey,
    required this.foreignKeys,
  });

  factory _DbTableMeta.fromJson(Map<String, dynamic> json) {
    final schema = (json['schema'] ?? json['schema_name'] ?? 'public')
        .toString();
    final name = (json['name'] ?? json['table_name'] ?? '').toString();
    final kind = (json['kind'] ?? json['table_type'] ?? json['type'] ?? 'table')
        .toString();
    final rawPk = json['primary_key'];
    final primaryKey = <String>[];
    if (rawPk is List) {
      for (final pk in rawPk) {
        final text = pk.toString().trim();
        if (text.isNotEmpty) primaryKey.add(text);
      }
    }

    final columns = <_DbColumnMeta>[];
    final rawColumns = json['columns'];
    if (rawColumns is List) {
      for (final col in rawColumns) {
        if (col is Map<String, dynamic>) {
          columns.add(_DbColumnMeta.fromJson(col, primaryKey));
        } else if (col is Map) {
          columns.add(
            _DbColumnMeta.fromJson(Map<String, dynamic>.from(col), primaryKey),
          );
        } else {
          final colName = col.toString();
          columns.add(
            _DbColumnMeta(
              name: colName,
              dataType: '',
              isNullable: true,
              isPrimaryKey: primaryKey.contains(colName),
            ),
          );
        }
      }
    }

    final fkListRaw = json['foreign_keys'];
    final foreignKeys = (fkListRaw is List)
        ? fkListRaw
              .whereType<Map>()
              .map(
                (entry) => DatabaseForeignKey.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList()
        : const <DatabaseForeignKey>[];

    return _DbTableMeta(
      schema: schema,
      name: name,
      kind: kind,
      rowCount: json['row_count'] is num
          ? (json['row_count'] as num).toInt()
          : (json['count'] is num ? (json['count'] as num).toInt() : null),
      columns: columns,
      primaryKey: primaryKey,
      foreignKeys: foreignKeys,
    );
  }

  String get fullName => '$schema.$name';

  bool get isView {
    final lower = kind.toLowerCase();
    return lower == 'view' ||
        lower == 'view table' ||
        lower == 'v' ||
        lower.contains('view');
  }

  DatabaseTable toDatabaseTable() {
    return DatabaseTable(
      name: name,
      schema: schema,
      rowCount: rowCount,
      columns: columns.map((col) => col.name).toList(growable: false),
      foreignKeys: foreignKeys,
      type: isView ? 'view' : 'table',
    );
  }
}

class _DbColumnMeta {
  final String name;
  final String dataType;
  final bool isNullable;
  final bool isPrimaryKey;

  const _DbColumnMeta({
    required this.name,
    required this.dataType,
    required this.isNullable,
    required this.isPrimaryKey,
  });

  factory _DbColumnMeta.fromJson(
    Map<String, dynamic> json,
    List<String> primaryKey,
  ) {
    final name = (json['name'] ?? '').toString();
    final isPk = json['is_primary_key'] == true || primaryKey.contains(name);
    return _DbColumnMeta(
      name: name,
      dataType: (json['data_type'] ?? json['type'] ?? '').toString(),
      isNullable: json['is_nullable'] != false,
      isPrimaryKey: isPk,
    );
  }
}

class _DbMigrationPlan {
  final String id;
  final String intent;
  final String status;
  final String createdAt;
  final int jobCount;
  final List<_DbMigrationJob> jobs;

  const _DbMigrationPlan({
    required this.id,
    required this.intent,
    required this.status,
    required this.createdAt,
    required this.jobCount,
    required this.jobs,
  });

  factory _DbMigrationPlan.fromJson(Map<String, dynamic> json) {
    final rawJobs = json['jobs'];
    final jobs = <_DbMigrationJob>[];
    if (rawJobs is List) {
      for (final job in rawJobs) {
        if (job is Map<String, dynamic>) {
          jobs.add(_DbMigrationJob.fromJson(job));
        } else if (job is Map) {
          jobs.add(_DbMigrationJob.fromJson(Map<String, dynamic>.from(job)));
        }
      }
    }
    return _DbMigrationPlan(
      id: (json['id'] ?? '').toString(),
      intent: (json['intent'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      jobCount: json['job_count'] is num
          ? (json['job_count'] as num).toInt()
          : jobs.length,
      jobs: jobs,
    );
  }
}

class _DbMigrationJob {
  final String id;
  final String stage;
  final String status;
  final String createdAt;
  final int? statementCount;

  const _DbMigrationJob({
    required this.id,
    required this.stage,
    required this.status,
    required this.createdAt,
    required this.statementCount,
  });

  factory _DbMigrationJob.fromJson(Map<String, dynamic> json) {
    return _DbMigrationJob(
      id: (json['id'] ?? '').toString(),
      stage: (json['stage'] ?? 'shadow').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      statementCount: json['statement_count'] is num
          ? (json['statement_count'] as num).toInt()
          : null,
    );
  }
}

enum _DbPrimaryTab { schema, data, migration }

enum _DbViewMode { tables, relations, graph }

class _DbBranchItem {
  final String id;
  final String name;
  final bool primary;

  const _DbBranchItem({
    required this.id,
    required this.name,
    required this.primary,
  });
}

class _DbGraphNode extends StatelessWidget {
  final DatabaseTable table;
  final Size size;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DbGraphNode({
    required this.table,
    required this.size,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isView = table.type == 'view';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size.width,
          height: size.height,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isView ? cs.tertiaryContainer : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isView ? Icons.visibility : Icons.table_chart,
                  size: 16,
                  color: isView ? cs.tertiary : cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      table.schema,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DbGraphPainter extends CustomPainter {
  final List<DatabaseTable> tables;
  final Map<String, Offset> positions;
  final Size nodeSize;
  final ColorScheme colorScheme;

  const _DbGraphPainter({
    required this.tables,
    required this.positions,
    required this.nodeSize,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = colorScheme.outlineVariant;

    final arrowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.outlineVariant;

    Offset centerOf(String fullName) {
      final p = positions[fullName];
      if (p == null) return Offset.zero;
      // Node is positioned with an extra (30,30) offset.
      return Offset(
        p.dx + 30 + nodeSize.width / 2,
        p.dy + 30 + nodeSize.height / 2,
      );
    }

    for (final table in tables) {
      final from = centerOf(table.fullName);
      if (from == Offset.zero) continue;
      for (final fk in table.foreignKeys) {
        final to = centerOf(fk.refFullTable);
        if (to == Offset.zero) continue;

        final path = Path()..moveTo(from.dx, from.dy);
        final midX = (from.dx + to.dx) / 2;
        path.cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
        canvas.drawPath(path, paint);

        // Arrow head.
        final dir = (to - from);
        final len = dir.distance;
        if (len > 1) {
          final ux = dir.dx / len;
          final uy = dir.dy / len;
          final tip = to;
          const s = 7.0;
          final left = Offset(
            tip.dx - ux * s - uy * (s * 0.6),
            tip.dy - uy * s + ux * (s * 0.6),
          );
          final right = Offset(
            tip.dx - ux * s + uy * (s * 0.6),
            tip.dy - uy * s - ux * (s * 0.6),
          );
          final arrow = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(right.dx, right.dy)
            ..close();
          canvas.drawPath(arrow, arrowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DbGraphPainter oldDelegate) {
    return oldDelegate.tables != tables ||
        oldDelegate.positions != positions ||
        oldDelegate.nodeSize != nodeSize ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _EnableDatabaseCard extends StatelessWidget {
  final bool enabling;
  final VoidCallback onEnable;

  const _EnableDatabaseCard({required this.enabling, required this.onEnable});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

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
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
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
                    _t(
                      context,
                      'project_database_enable_title',
                      'Enable Database',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      context,
                      'project_database_enable_hint',
                      'Provision a Neon PostgreSQL database for this project and start exploring your schema and data.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.cloud_outlined,
                    text: _t(
                      context,
                      'project_database_feature_serverless',
                      'Serverless Postgres on Neon',
                    ),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.lock_outline,
                    text: _t(
                      context,
                      'project_database_feature_ssl',
                      'Secure SSL connections',
                    ),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.alt_route_outlined,
                    text: _t(
                      context,
                      'project_database_feature_branching',
                      'Branching support',
                    ),
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
                      label: Text(
                        enabling
                            ? _t(
                                context,
                                'project_database_enabling',
                                'Enabling...',
                              )
                            : _t(
                                context,
                                'project_database_enable_action',
                                'Enable Database',
                              ),
                      ),
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
