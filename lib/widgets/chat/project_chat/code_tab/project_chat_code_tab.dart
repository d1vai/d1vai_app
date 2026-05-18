import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/d1vai_service.dart';
import '../../../../services/local_workspace_service.dart';
import '../../../../providers/editor_preferences_provider.dart';
import '../../../snackbar_helper.dart';
import 'code_tab_file_viewer.dart';
import 'code_tab_file_viewer_page.dart';
import 'code_tab_models.dart';
import 'code_tab_tree_panel.dart';
import 'code_tab_types.dart';
import 'code_workbench_controller.dart';

class ProjectChatCodeTab extends StatefulWidget {
  final String projectId;
  final ValueChanged<String> onAsk;

  const ProjectChatCodeTab({
    super.key,
    required this.projectId,
    required this.onAsk,
  });

  @override
  State<ProjectChatCodeTab> createState() => _ProjectChatCodeTabState();
}

class _ProjectChatCodeTabState extends State<ProjectChatCodeTab> {
  final D1vaiService _service = D1vaiService();
  final LocalWorkspaceService _localWorkspaceService =
      const LocalWorkspaceService();
  final TextEditingController _searchController = TextEditingController();
  late final CodeWorkbenchController _workbench;
  late final VoidCallback _searchListener;
  late final VoidCallback _workbenchListener;
  EditorPreferencesProvider? _editorPreferences;
  EditorEngine? _lastEditorEngine;

  bool _loadingTree = false;
  String? _treeError;
  CodeTabFileNode? _root;
  final Set<String> _expandedDirs = <String>{''};
  List<CodeTabFlatNode> _flat = const [];
  double _desktopTreePaneWidth = 320;
  final Map<String, Timer> _syncTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _workbench = CodeWorkbenchController(service: _service);
    _workbenchListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _workbench.addListener(_workbenchListener);
    _loadTree();
    _searchListener = () {
      if (!mounted) return;
      _rebuildFlatList();
    };
    _searchController.addListener(_searchListener);
  }

  @override
  void dispose() {
    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();
    _searchController.removeListener(_searchListener);
    _searchController.dispose();
    _editorPreferences?.removeListener(_handleEditorPreferencesChanged);
    _workbench.removeListener(_workbenchListener);
    _workbench.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<EditorPreferencesProvider>();
    if (identical(_editorPreferences, next)) return;
    _editorPreferences?.removeListener(_handleEditorPreferencesChanged);
    _editorPreferences = next;
    _editorPreferences?.addListener(_handleEditorPreferencesChanged);
    _handleEditorPreferencesChanged();
  }

  void _handleEditorPreferencesChanged() {
    final prefs = _editorPreferences;
    if (prefs == null) return;
    _lastEditorEngine ??= prefs.engine;
    unawaited(
      _workbench.applyEditorPreferences(
        defaultWrap: prefs.defaultWrap,
        tabSize: prefs.tabSize,
        engine: prefs.engine,
      ),
    );
    _lastEditorEngine = prefs.engine;
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  bool _isMacDesktop(BuildContext context) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.macOS &&
      !_isMobile(context);

  Future<void> _loadTree() async {
    if (_loadingTree) return;
    setState(() {
      _loadingTree = true;
      _treeError = null;
      _root = null;
      _flat = const [];
      _expandedDirs
        ..clear()
        ..add('');
    });
    try {
      final raw = _workbench.hasLocalWorkspace
          ? (await _localWorkspaceService.readTree(
              _workbench.localRootPath!,
            )).root
          : await _service.getProjectStorageStructure(widget.projectId);
      if (!mounted) return;
      final node = CodeTabFileNode.fromJson(raw);
      setState(() {
        _root = node;
      });
      _rebuildFlatList();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _treeError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTree = false;
        });
      }
    }
  }

  void _rebuildFlatList() {
    final next = _buildFlatList();
    if (!mounted) return;
    setState(() {
      _flat = next;
    });
  }

  List<CodeTabFlatNode> _buildFlatList() {
    final root = _root;
    if (root == null) return const [];

    final q = _searchController.text.trim().toLowerCase();
    final out = <CodeTabFlatNode>[];

    void walk(CodeTabFileNode node, String parentPath, int depth) {
      final rel = parentPath.isEmpty ? node.name : '$parentPath/${node.name}';
      final match =
          q.isEmpty ||
          node.name.toLowerCase().contains(q) ||
          rel.toLowerCase().contains(q);
      if (match) {
        out.add(CodeTabFlatNode(node: node, path: rel, depth: depth));
      }

      if (!node.isDirectory) return;

      final dirKey = rel;
      final expanded = q.isNotEmpty ? true : _expandedDirs.contains(dirKey);
      if (!expanded) return;

      final children = node.children;
      if (children == null || children.isEmpty) return;

      for (final c in children) {
        walk(c, rel, depth + 1);
      }
    }

    final top = root.children;
    if (top != null) {
      for (final c in top) {
        walk(c, '', 0);
      }
    }

    if (q.isNotEmpty) {
      out.sort((a, b) {
        final la = a.path.length;
        final lb = b.path.length;
        if (la != lb) return la.compareTo(lb);
        return a.path.compareTo(b.path);
      });
    }

    return out;
  }

  void _toggleDir(String dirPath) {
    setState(() {
      if (_expandedDirs.contains(dirPath)) {
        _expandedDirs.remove(dirPath);
      } else {
        _expandedDirs.add(dirPath);
      }
    });
    _rebuildFlatList();
  }

  Future<bool> _confirmActionForPath(
    String path, {
    required String title,
    required String message,
  }) async {
    final editor = _workbench.editorForPath(path);
    if (editor == null || !editor.hasUnsavedChanges) return true;

    final result = await showDialog<CodeTabEditLeaveAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(CodeTabEditLeaveAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(CodeTabEditLeaveAction.discard),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(CodeTabEditLeaveAction.save),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result == CodeTabEditLeaveAction.cancel) return false;
    if (result == CodeTabEditLeaveAction.discard) {
      await _workbench.discardChanges(path);
      return true;
    }

    return await _saveEditor(path);
  }

  Future<bool> _saveEditor(String path) async {
    try {
      final active = _workbench.editorForPath(path);
      String? commitSha;
      if (_workbench.hasLocalWorkspace &&
          _workbench.localRootPath != null &&
          active != null) {
        final latestText = await active.controller.readText(refresh: true);
        await _localWorkspaceService.writeFile(
          _workbench.localRootPath!,
          path,
          latestText,
        );
        _scheduleDeferredGitHubSync(path);
        _workbench.markPathLocalSaved(path);
        if (!mounted) return false;
        SnackBarHelper.showSuccess(
          context,
          title: 'Saved locally',
          message: 'Local workspace updated. Syncing in the background.',
        );
        return true;
      }
      commitSha = await _workbench.saveEditor(widget.projectId, path);
      if (!mounted) return false;
      final shortSha = (commitSha != null && commitSha.length >= 7)
          ? commitSha.substring(0, 7)
          : null;
      SnackBarHelper.showSuccess(
        context,
        title: 'Saved',
        message: shortSha == null
            ? 'Saved successfully'
            : 'Saved (commit: $shortSha)',
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      SnackBarHelper.showError(
        context,
        title: 'Save failed',
        message: e.toString(),
      );
      return false;
    }
  }

  void _scheduleDeferredGitHubSync(String path) {
    _syncTimers[path]?.cancel();
    _syncTimers[path] = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      unawaited(() async {
        final editor = _workbench.editorForPath(path);
        if (editor == null) return;
        final latestText = await editor.controller.readText(refresh: true);
        if (latestText != editor.originalContent) {
          _workbench.markPathQueued(path);
          _scheduleDeferredGitHubSync(path);
          return;
        }
        _workbench.markPathSyncingGitHub(path);
        await _syncLocalPathToGitHub(path);
      }());
    });
  }

  Future<void> _syncLocalPathToGitHub(String path) async {
    final editor = _workbench.editorForPath(path);
    if (editor == null || editor.content == null) return;
    try {
      final fileName = path.split('/').isEmpty ? 'file' : path.split('/').last;
      final latestText = await editor.controller.readText(refresh: true);
      final result = await _service.syncFileToGitHub(
        widget.projectId,
        filePath: path,
        content: latestText,
        commitMessage: 'feat: update $fileName',
      );
      final commit = result['commit'];
      final commitSha = commit is Map<String, dynamic>
          ? commit['sha']?.toString()
          : null;
      if (!mounted) return;
      _workbench.markPathSynced(path);
      final shortSha = (commitSha != null && commitSha.length >= 7)
          ? commitSha.substring(0, 7)
          : null;
      SnackBarHelper.showSuccess(
        context,
        title: 'Synced',
        message: shortSha == null
            ? 'Synced to GitHub'
            : 'Synced to GitHub ($shortSha)',
      );
    } catch (e) {
      if (!mounted) return;
      _workbench.markPathDirty(path);
      SnackBarHelper.showError(
        context,
        title: 'Sync failed',
        message: e.toString(),
      );
    }
  }

  Widget _buildSyncStatusPill(
    BuildContext context,
    CodeWorkbenchSyncState state,
  ) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (state) {
      CodeWorkbenchSyncState.localSaved => (
        Icons.save_outlined,
        'Saved locally',
        theme.colorScheme.primary,
      ),
      CodeWorkbenchSyncState.queued => (
        Icons.schedule,
        'Queued to sync',
        Colors.orange,
      ),
      CodeWorkbenchSyncState.syncingGitHub => (
        Icons.sync,
        'Syncing to GitHub',
        theme.colorScheme.tertiary,
      ),
      CodeWorkbenchSyncState.syncingCloud => (
        Icons.cloud_sync_outlined,
        'Syncing cloud',
        theme.colorScheme.secondary,
      ),
      CodeWorkbenchSyncState.synced => (
        Icons.check_circle_outline,
        'Synced',
        Colors.green,
      ),
      CodeWorkbenchSyncState.failed => (
        Icons.error_outline,
        'Sync failed',
        Colors.redAccent,
      ),
      CodeWorkbenchSyncState.idle => (
        Icons.cloud_outlined,
        _workbench.hasLocalWorkspace ? 'Local workspace' : 'Cloud workspace',
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDesktopFile(String path, {required bool preview}) async {
    final prefs = context.read<EditorPreferencesProvider>();
    if (preview && !_workbench.canReplacePreviewWith(path)) {
      final previewPath = _workbench.previewPath;
      if (previewPath == null) return;
      final ok = await _confirmActionForPath(
        previewPath,
        title: 'Unsaved changes',
        message: 'Save changes before replacing the preview tab?',
      );
      if (!ok) return;
    }

    if (_workbench.hasLocalWorkspace && _workbench.localRootPath != null) {
      final existing = _workbench.editorForPath(path);
      if (existing == null) {
        await _workbench.openFile(
          widget.projectId,
          path,
          preview: preview,
          wrapEnabled: prefs.defaultWrap,
          tabSize: prefs.tabSize,
          engine: prefs.engine,
        );
        final raw = await _localWorkspaceService.readFile(
          _workbench.localRootPath!,
          path,
        );
        final editor = _workbench.editorForPath(path);
        if (editor != null) {
          _workbench.setFileContent(
            path,
            content: CodeTabFileContent(
              path: raw.path,
              content: raw.content,
              size: raw.size,
              isBinary: raw.isBinary,
            ),
          );
        }
        return;
      }
    }

    await _workbench.openFile(
      widget.projectId,
      path,
      preview: preview,
      wrapEnabled: prefs.defaultWrap,
      tabSize: prefs.tabSize,
      engine: prefs.engine,
    );
  }

  Future<void> _closeEditor(String path) async {
    final ok = await _confirmActionForPath(
      path,
      title: 'Unsaved changes',
      message: 'Save changes before closing this file?',
    );
    if (!ok) return;
    _workbench.closeEditor(path);
  }

  void _askAboutSelected() {
    final p = _workbench.activePath;
    if (p == null || p.isEmpty) return;
    widget.onAsk(
      'Please review the file "$p". Summarize what it does and propose improvements. '
      'If there are bugs or missing pieces, suggest concrete edits.',
    );
  }

  Future<void> _copyActiveFile() async {
    final active = _workbench.activeEditor;
    final content = active?.content;
    if (active == null || content == null) return;
    final latestText = await active.controller.readText(refresh: true);
    await Clipboard.setData(ClipboardData(text: latestText));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'File content copied',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = _isMobile(context);
    final compact = _isMacDesktop(context);
    final q = _searchController.text.trim();
    final activeEditor = _workbench.activeEditor;
    final hasSelection =
        _workbench.activePath != null && _workbench.activePath!.isNotEmpty;
    final activeSyncState = activeEditor == null
        ? CodeWorkbenchSyncState.idle
        : _workbench.syncStateFor(activeEditor.path);

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search files…',
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: compact ? 10 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear',
                          ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              _ToolbarIconButton(
                onPressed: _loadingTree ? null : _loadTree,
                compact: compact,
                icon: Icons.refresh_outlined,
                tooltip: 'Refresh',
              ),
              SizedBox(width: compact ? 2 : 6),
              if (activeEditor != null && activeEditor.isEditing) ...[
                _ToolbarIconButton(
                  onPressed: activeEditor.controller.showSearch,
                  compact: compact,
                  icon: Icons.search_outlined,
                  tooltip: 'Find',
                ),
                const SizedBox(width: 2),
                _ToolbarIconButton(
                  onPressed: () =>
                      unawaited(_workbench.toggleWrap(activeEditor.path)),
                  compact: compact,
                  icon: activeEditor.wrapEnabled
                      ? Icons.wrap_text
                      : Icons.wrap_text_outlined,
                  tooltip: activeEditor.wrapEnabled
                      ? 'Disable wrap'
                      : 'Enable wrap',
                ),
                const SizedBox(width: 2),
                if (activeEditor.controller.supportsFoldAll)
                  _FoldActionsMenu(
                    compact: compact,
                    onFoldAll: activeEditor.controller.foldAll,
                    onUnfoldAll: activeEditor.controller.unfoldAll,
                    onFoldImports: activeEditor.controller.supportsFoldImports
                        ? activeEditor.controller.foldImports
                        : null,
                    onFoldHeader: activeEditor.controller.supportsFoldHeader
                        ? activeEditor.controller.foldHeader
                        : null,
                  ),
                if (activeEditor.controller.supportsFoldAll)
                  const SizedBox(width: 2),
                ListenableBuilder(
                  listenable: activeEditor.controller,
                  builder: (context, _) {
                    return _ToolbarIconButton(
                      onPressed:
                          activeEditor.saving || !activeEditor.hasUnsavedChanges
                          ? null
                          : () => _saveEditor(activeEditor.path),
                      compact: compact,
                      icon: Icons.save_outlined,
                      tooltip: 'Save',
                      busy: activeEditor.saving,
                    );
                  },
                ),
                const SizedBox(width: 2),
              ],
              _ToolbarIconButton(
                onPressed: hasSelection ? _askAboutSelected : null,
                compact: compact,
                icon: Icons.auto_awesome_outlined,
                tooltip: 'Ask AI about file',
              ),
              const SizedBox(width: 8),
              _buildSyncStatusPill(context, activeSyncState),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Expanded(
            child: mobile
                ? CodeTabTreePanel(
                    loading: _loadingTree,
                    error: _treeError,
                    searchQuery: q,
                    list: _flat,
                    selectedFilePath: _workbench.selectedTreePath,
                    expandedDirs: _expandedDirs,
                    compact: false,
                    onReload: _loadTree,
                    onToggleDir: _toggleDir,
                    onPreviewFile: (p) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CodeTabFileViewerPage(
                            projectId: widget.projectId,
                            filePath: p,
                            onAsk: (prompt) {
                              widget.onAsk(prompt);
                            },
                          ),
                        ),
                      );
                    },
                    onOpenFile: (p) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CodeTabFileViewerPage(
                            projectId: widget.projectId,
                            filePath: p,
                            onAsk: (prompt) {
                              widget.onAsk(prompt);
                            },
                          ),
                        ),
                      );
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const handleWidth = 18.0;
                      const minTreeWidth = 220.0;
                      const maxTreeWidth = 560.0;
                      final available = constraints.maxWidth;
                      final clampedTreeWidth = _desktopTreePaneWidth.clamp(
                        minTreeWidth,
                        (available - handleWidth - 280).clamp(
                          minTreeWidth,
                          maxTreeWidth,
                        ),
                      );
                      if (clampedTreeWidth != _desktopTreePaneWidth) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _desktopTreePaneWidth = clampedTreeWidth;
                          });
                        });
                      }

                      return Row(
                        children: [
                          SizedBox(
                            width: clampedTreeWidth,
                            child: CodeTabTreePanel(
                              loading: _loadingTree,
                              error: _treeError,
                              searchQuery: q,
                              list: _flat,
                              selectedFilePath: _workbench.selectedTreePath,
                              expandedDirs: _expandedDirs,
                              compact: compact,
                              onReload: _loadTree,
                              onToggleDir: _toggleDir,
                              onPreviewFile: (p) async {
                                await _openDesktopFile(p, preview: true);
                              },
                              onOpenFile: (p) async {
                                await _openDesktopFile(p, preview: false);
                              },
                            ),
                          ),
                          _isMacDesktop(context)
                              ? _CodePaneResizeHandle(
                                  onDragDelta: (delta) {
                                    setState(() {
                                      _desktopTreePaneWidth =
                                          (_desktopTreePaneWidth + delta).clamp(
                                            minTreeWidth,
                                            maxTreeWidth,
                                          );
                                    });
                                  },
                                )
                              : const SizedBox(width: 12),
                          Expanded(
                            child: CodeTabFileViewer(
                              theme: theme,
                              editors: _workbench.openEditors,
                              activeEditor: activeEditor,
                              compact: compact,
                              isSynced: _workbench.isPathSynced,
                              syncStateFor: _workbench.syncStateFor,
                              queuedDurationFor: _workbench.queuedDurationFor,
                              onSelectTab: _workbench.activateEditor,
                              onPinTab: _workbench.pinEditor,
                              onCloseTab: (path) async {
                                await _closeEditor(path);
                              },
                              onEnterEdit: activeEditor == null
                                  ? null
                                  : () {
                                      _workbench.enterEditMode(
                                        activeEditor.path,
                                      );
                                    },
                              onCancelEdit: activeEditor == null
                                  ? null
                                  : () async {
                                      final ok = await _confirmActionForPath(
                                        activeEditor.path,
                                        title: 'Unsaved changes',
                                        message:
                                            'Save changes before leaving edit mode?',
                                      );
                                      if (!ok) return;
                                      await _workbench.cancelEdit(
                                        activeEditor.path,
                                      );
                                    },
                              onToggleWrap: activeEditor == null
                                  ? null
                                  : () => unawaited(
                                      _workbench.toggleWrap(activeEditor.path),
                                    ),
                              onChange: null,
                              onSave: activeEditor == null
                                  ? null
                                  : () => _saveEditor(activeEditor.path),
                              onCopy: activeEditor == null
                                  ? null
                                  : _copyActiveFile,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CodePaneResizeHandle extends StatefulWidget {
  final ValueChanged<double> onDragDelta;

  const _CodePaneResizeHandle({required this.onDragDelta});

  @override
  State<_CodePaneResizeHandle> createState() => _CodePaneResizeHandleState();
}

class _CodePaneResizeHandleState extends State<_CodePaneResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary.withValues(
      alpha: _dragging
          ? 0.90
          : _hovering
          ? 0.55
          : 0.24,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() {
            _dragging = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          widget.onDragDelta(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _dragging = false;
          });
        },
        onHorizontalDragCancel: () {
          setState(() {
            _dragging = false;
          });
        },
        child: SizedBox(
          width: 18,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _dragging ? 4 : 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final bool compact;
  final bool busy;

  const _ToolbarIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.compact = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: compact ? 15 : 16,
      splashRadius: compact ? 15 : 16,
      padding: EdgeInsets.all(compact ? 4 : 5),
      color: theme.colorScheme.onSurfaceVariant.withValues(
        alpha: onPressed == null ? 0.38 : 0.78,
      ),
      icon: busy
          ? SizedBox(
              width: compact ? 14 : 15,
              height: compact ? 14 : 15,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      tooltip: tooltip,
    );
  }
}

class _FoldActionsMenu extends StatelessWidget {
  final VoidCallback onFoldAll;
  final VoidCallback onUnfoldAll;
  final VoidCallback? onFoldImports;
  final VoidCallback? onFoldHeader;
  final bool compact;

  const _FoldActionsMenu({
    required this.onFoldAll,
    required this.onUnfoldAll,
    required this.onFoldImports,
    required this.onFoldHeader,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Fold options',
      padding: EdgeInsets.zero,
      iconSize: compact ? 15 : 16,
      splashRadius: compact ? 15 : 16,
      icon: Icon(
        Icons.unfold_more_outlined,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
      ),
      onSelected: (action) => action(),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<VoidCallback>>[
          PopupMenuItem(value: onFoldAll, child: const Text('Fold all')),
          PopupMenuItem(value: onUnfoldAll, child: const Text('Unfold all')),
        ];
        if (onFoldImports != null) {
          items.add(
            PopupMenuItem(
              value: onFoldImports!,
              child: const Text('Fold imports'),
            ),
          );
        }
        if (onFoldHeader != null) {
          items.add(
            PopupMenuItem(
              value: onFoldHeader!,
              child: const Text('Fold header'),
            ),
          );
        }
        return items;
      },
    );
  }
}
