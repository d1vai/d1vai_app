import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../file_type_visual.dart';
import 'code_tab_models.dart';
import 'code_tab_views.dart';

class CodeTabTreePanel extends StatefulWidget {
  final bool loading;
  final String? error;
  final String searchQuery;
  final List<CodeTabFlatNode> list;
  final String? selectedPath;
  final Set<String> expandedDirs;
  final bool compact;
  final bool allowRename;
  final VoidCallback onReload;
  final void Function(String dirPath) onToggleDir;
  final void Function(String path, bool isDirectory) onSelectItem;
  final Future<void> Function(String path) onOpenFile;
  final Future<void> Function(String path, bool isDirectory)? onRenameItem;

  const CodeTabTreePanel({
    super.key,
    required this.loading,
    required this.error,
    required this.searchQuery,
    required this.list,
    required this.selectedPath,
    required this.expandedDirs,
    required this.compact,
    this.allowRename = false,
    required this.onReload,
    required this.onToggleDir,
    required this.onSelectItem,
    required this.onOpenFile,
    this.onRenameItem,
  });

  @override
  State<CodeTabTreePanel> createState() => _CodeTabTreePanelState();
}

class _CodeTabTreePanelState extends State<CodeTabTreePanel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'code_tree_panel');
  static const List<String> _loadingMessages = <String>[
    'indexing workspace',
    'mapping folders',
    'hydrating file nodes',
    'warming editor state',
  ];
  int _loadingTick = 0;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _syncLoadingTimer();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeTabTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) {
      _syncLoadingTimer();
    }
  }

  void _syncLoadingTimer() {
    _loadingTimer?.cancel();
    if (!widget.loading) return;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted) return;
      setState(() {
        _loadingTick = (_loadingTick + 1) % 2400;
      });
    });
  }

  Future<void> _triggerRename() async {
    if (!widget.allowRename) return;
    final selectedPath = (widget.selectedPath ?? '').trim();
    if (selectedPath.isEmpty) return;
    final selectedNode = widget.list
        .where((item) => item.path == selectedPath)
        .cast<CodeTabFlatNode?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (selectedNode == null) return;
    await widget.onRenameItem?.call(
      selectedNode.path,
      selectedNode.node.isDirectory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowVertical = widget.compact ? 3.0 : 4.0;
    final rowHorizontal = widget.compact ? 6.0 : 7.0;
    final indentUnit = widget.compact ? 7.0 : 8.0;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          unawaited(_triggerRename());
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          unawaited(_triggerRename());
        },
      },
      child: Focus(
        focusNode: _focusNode,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.loading
              ? _CodeTreeLoadingState(
                  compact: widget.compact,
                  tick: _loadingTick,
                  message:
                      _loadingMessages[(_loadingTick ~/ 4) %
                          _loadingMessages.length],
                )
              : widget.error != null
              ? CodeTabErrorView(
                  title: 'Failed to load files',
                  message: widget.error!,
                  onRetry: widget.onReload,
                )
              : widget.list.isEmpty
              ? CodeTabEmptyView(
                  text: widget.searchQuery.isEmpty
                      ? 'No files found'
                      : 'No matches',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  itemBuilder: (context, index) {
                    final item = widget.list[index];
                    final isDir = item.node.isDirectory;
                    final path = item.path;
                    final selected = path == widget.selectedPath;
                    final dirExpanded =
                        isDir && widget.expandedDirs.contains(path);

                    return _CodeTreeRow(
                      compact: widget.compact,
                      item: item,
                      selected: selected,
                      dirExpanded: dirExpanded,
                      indentUnit: indentUnit,
                      rowHorizontal: rowHorizontal,
                      rowVertical: rowVertical,
                      onTap: () async {
                        _focusNode.requestFocus();
                        widget.onSelectItem(path, isDir);
                        if (isDir) {
                          widget.onToggleDir(path);
                          return;
                        }
                        await widget.onOpenFile(path);
                      },
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 1),
                  itemCount: widget.list.length,
                ),
        ),
      ),
    );
  }
}

class _CodeTreeLoadingState extends StatelessWidget {
  final bool compact;
  final int tick;
  final String message;

  const _CodeTreeLoadingState({
    required this.compact,
    required this.tick,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = ((tick % 100) / 100).clamp(0.0, 1.0);
    final barHeight = compact ? 5.0 : 6.0;
    final lineColor = cs.primary.withValues(alpha: 0.85);
    final dim = cs.onSurfaceVariant.withValues(alpha: 0.72);
    final panel = cs.surface.withValues(alpha: 0.46);

    Widget traceLine(String text, {required bool active}) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? cs.tertiary.withValues(alpha: 0.95)
                  : cs.primary.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: compact ? 10.5 : 11.0,
                color: active ? cs.onSurface : dim,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: compact ? 15 : 16,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Explorer',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: compact ? 11.0 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: dim,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '> $message',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: compact ? 11.0 : 11.5,
                    color: lineColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: barHeight,
                    color: cs.onSurface.withValues(alpha: 0.08),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: progress < 0.08 ? 0.08 : progress,
                          child: Container(color: lineColor),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.22,
                            child: Transform.translate(
                              offset: Offset(progress * 180, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      cs.tertiary.withValues(alpha: 0.95),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                traceLine(
                  'scan ./${message.replaceAll(' ', '_')}',
                  active: true,
                ),
                const SizedBox(height: 6),
                traceLine('resolve nested modules', active: progress > 0.22),
                const SizedBox(height: 6),
                traceLine('compose tree snapshot', active: progress > 0.56),
              ],
            ),
          ),
          const Spacer(),
          Opacity(
            opacity: 0.82,
            child: Text(
              'Loading files...',
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                color: dim,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTreeRow extends StatefulWidget {
  final bool compact;
  final CodeTabFlatNode item;
  final bool selected;
  final bool dirExpanded;
  final double indentUnit;
  final double rowHorizontal;
  final double rowVertical;
  final Future<void> Function() onTap;

  const _CodeTreeRow({
    required this.compact,
    required this.item,
    required this.selected,
    required this.dirExpanded,
    required this.indentUnit,
    required this.rowHorizontal,
    required this.rowVertical,
    required this.onTap,
  });

  @override
  State<_CodeTreeRow> createState() => _CodeTreeRowState();
}

class _CodeTreeRowState extends State<_CodeTreeRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = widget.item.node.isDirectory;
    final path = widget.item.path;
    final baseBg = widget.selected
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : _hovering
        ? theme.colorScheme.onSurface.withValues(alpha: 0.055)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: () => unawaited(widget.onTap()),
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.rowHorizontal,
            vertical: widget.rowVertical,
          ),
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SizedBox(width: widget.indentUnit * widget.item.depth),
              SizedBox(
                width: widget.compact ? 15 : 16,
                height: widget.compact ? 15 : 16,
                child: Center(
                  child: isDir
                      ? buildFolderTypeIcon(
                          context,
                          path,
                          expanded: widget.dirExpanded,
                          size: widget.compact ? 15 : 16,
                          fallbackColor: theme.colorScheme.secondary,
                        )
                      : buildFileTypeIcon(
                          context,
                          widget.item.node.name,
                          size: widget.compact ? 15 : 16,
                          fallbackColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.item.node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.compact ? 11.5 : 12.0,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (isDir)
                Icon(
                  widget.dirExpanded ? Icons.expand_less : Icons.expand_more,
                  size: widget.compact ? 14 : 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
