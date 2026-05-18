import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../services/d1vai_service.dart';
import '../../../../services/local_workspace_service.dart';
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
  final LocalWorkspaceService _localWorkspaceService = const LocalWorkspaceService();
  final TextEditingController _searchController = TextEditingController();
  late final CodeWorkbenchController _workbench;
  late final VoidCallback _searchListener;
  late final VoidCallback _workbenchListener;

  bool _loadingTree = false;
  String? _treeError;
  CodeTabFileNode? _root;
  final Set<String> _expandedDirs = <String>{''};
  List<CodeTabFlatNode> _flat = const [];
  double _desktopTreePaneWidth = 320;
  bool _loadingLocalWorkspace = false;

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
    _searchController.removeListener(_searchListener);
    _searchController.dispose();
    _workbench.removeListener(_workbenchListener);
    _workbench.dispose();
    super.dispose();
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
          ? (await _localWorkspaceService.readTree(_workbench.localRootPath!)).root
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
      _workbench.discardChanges(path);
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
        await _localWorkspaceService.writeFile(
          _workbench.localRootPath!,
          path,
          active.controller.text,
        );
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

  Future<void> _openDesktopFile(
    String path, {
    required bool preview,
  }) async {
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
        await _workbench.openFile(widget.projectId, path, preview: preview);
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

    await _workbench.openFile(widget.projectId, path, preview: preview);
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

  Future<void> _pickAndAttachLocalFolder() async {
    if (_loadingLocalWorkspace || !_isMacDesktop(context)) return;
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null || selected.trim().isEmpty) return;
    await _attachLocalFolder(selected);
  }

  Future<void> _attachLocalFolder(String path) async {
    if (_loadingLocalWorkspace) return;
    setState(() {
      _loadingLocalWorkspace = true;
    });
    try {
      final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');
      if (normalized.isEmpty) return;
      final name = normalized.split('/').last;
      _workbench.attachLocalWorkspace(rootPath: normalized, rootName: name);
      await _loadTree();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Local folder attached',
        message: 'Browsing $name with local-first edits on macOS.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Attach failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocalWorkspace = false;
        });
      }
    }
  }

  Future<void> _detachLocalFolder() async {
    if (_loadingLocalWorkspace) return;
    final dirty = _workbench.openEditors.any((editor) => editor.hasUnsavedChanges);
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Detach local folder'),
          content: const Text(
            'Unsaved local changes will remain in open tabs. Detach the folder now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Detach'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    _workbench.clearLocalWorkspace();
    await _loadTree();
  }

  Future<void> _copyActiveFile() async {
    final active = _workbench.activeEditor;
    final content = active?.content;
    if (active == null || content == null) return;
    await Clipboard.setData(ClipboardData(text: active.controller.text));
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
    final localWorkspaceLabel = _workbench.localRootName;

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _WorkbenchBadge(
                    label: _workbench.sourceMode == CodeWorkbenchSourceMode.cloudOnly
                        ? 'Cloud workspace'
                        : 'Hybrid workspace',
                    icon: _workbench.sourceMode == CodeWorkbenchSourceMode.cloudOnly
                        ? Icons.cloud_done_outlined
                        : Icons.sync_outlined,
                  ),
                  if (localWorkspaceLabel != null && localWorkspaceLabel.isNotEmpty)
                    _WorkbenchBadge(
                      label: localWorkspaceLabel,
                      icon: Icons.folder_open,
                    ),
                  TextButton.icon(
                    onPressed: _loadingLocalWorkspace ? null : _pickAndAttachLocalFolder,
                    icon: _loadingLocalWorkspace
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder),
                    label: Text(
                      _workbench.hasLocalWorkspace ? 'Switch Folder' : 'Open Folder',
                    ),
                  ),
                  if (_workbench.hasLocalWorkspace)
                    TextButton.icon(
                      onPressed: _detachLocalFolder,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Detach'),
                    ),
                ],
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
          ],
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
              IconButton(
                onPressed: _loadingTree ? null : _loadTree,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              SizedBox(width: compact ? 2 : 6),
              if (activeEditor != null && activeEditor.isEditing) ...[
                IconButton(
                  onPressed:
                      activeEditor.saving || !activeEditor.hasUnsavedChanges
                      ? null
                      : () => _saveEditor(activeEditor.path),
                  icon: activeEditor.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  tooltip: 'Save',
                ),
                const SizedBox(width: 2),
              ],
              IconButton(
                onPressed: hasSelection ? _askAboutSelected : null,
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Ask AI about file',
              ),
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
                              onSelectTab: _workbench.activateEditor,
                              onPinTab: _workbench.pinEditor,
                              onCloseTab: (path) async {
                                await _closeEditor(path);
                              },
                              onEnterEdit: activeEditor == null
                                  ? null
                                  : () {
                                      _workbench.enterEditMode(activeEditor.path);
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
                                      _workbench.cancelEdit(activeEditor.path);
                                    },
                              onChange: activeEditor == null
                                  ? null
                                  : (v) {
                                      setState(() {});
                                    },
                              onSave: activeEditor == null
                                  ? null
                                  : () => _saveEditor(activeEditor.path),
                              onCopy: activeEditor == null ? null : _copyActiveFile,
                              onAsk: hasSelection ? _askAboutSelected : null,
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
      alpha: _dragging ? 0.90 : _hovering ? 0.55 : 0.24,
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

class _WorkbenchBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _WorkbenchBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
