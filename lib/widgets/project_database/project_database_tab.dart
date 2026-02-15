import 'package:flutter/material.dart';
import 'dart:async';

import '../../models/database_table.dart';
import '../../models/project.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
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
  _DbViewMode _viewMode = _DbViewMode.tables;

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
      // Backend returns either:
      // - { tables: [...] } (new introspect)
      // - { schemas: [{ tables: [...] }] } (legacy)
      final rawTables = schemaData['tables'];
      if (rawTables is List) {
        for (final t in rawTables) {
          if (t is Map<String, dynamic>) {
            tables.add(DatabaseTable.fromJson(t));
          } else if (t is Map) {
            tables.add(DatabaseTable.fromJson(Map<String, dynamic>.from(t)));
          }
        }
      } else if (schemaData['schemas'] is List) {
        for (final schema in (schemaData['schemas'] as List)) {
          if (schema is! Map) continue;
          final st = schema['tables'];
          if (st is! List) continue;
          for (final table in st) {
            if (table is Map<String, dynamic>) {
              tables.add(DatabaseTable.fromJson(table));
            } else if (table is Map) {
              tables.add(
                DatabaseTable.fromJson(Map<String, dynamic>.from(table)),
              );
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
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/db/schema',
        );
        return;
      }
      SnackBarHelper.showError(context, title: 'Error', message: msg);
    }
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
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint:
              '/api/projects/${widget.project.id}/integrations/database/activate',
        );
        return;
      }
      SnackBarHelper.showError(context, title: 'Error', message: msg);
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
            Icon(
              Icons.storage,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No database tables',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SegmentedButton<_DbViewMode>(
            segments: const [
              ButtonSegment(
                value: _DbViewMode.tables,
                icon: Icon(Icons.table_chart),
                label: Text('Tables'),
              ),
              ButtonSegment(
                value: _DbViewMode.relations,
                icon: Icon(Icons.account_tree),
                label: Text('Relations'),
              ),
              ButtonSegment(
                value: _DbViewMode.graph,
                icon: Icon(Icons.hub),
                label: Text('Graph'),
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

  Widget _buildTablesList(ThemeData theme) {
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                if (table.foreignKeys.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${table.foreignKeys.length} relations',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
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

  Widget _buildRelationsList(ThemeData theme) {
    final withRelations =
        _tables.where((t) => t.foreignKeys.isNotEmpty).toList(growable: false)
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    if (withRelations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No foreign-key relationships found.',
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
              '${table.foreignKeys.length} relations',
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
                    'Explain the relationship from ${table.fullName}.${fk.columnName} '
                    'to ${fk.refFullTable}.${fk.refColumn}. Suggest indexes and common queries.',
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
            'Add more tables to see relationships as a graph.',
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
                    final question =
                        'Given the database schema, explain how "${t.fullName}" relates to other tables (foreign keys) and suggest improvements.';
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

enum _DbViewMode { tables, relations, graph }

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
