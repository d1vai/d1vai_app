import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/d1vai_service.dart';
import '../../../snackbar_helper.dart';
import 'code_tab_file_viewer.dart';
import 'code_tab_file_viewer_page.dart';
import 'code_tab_models.dart';
import 'code_tab_tree_panel.dart';
import 'code_tab_types.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  late final VoidCallback _searchListener;

  bool _loadingTree = false;
  String? _treeError;
  CodeTabFileNode? _root;
  final Set<String> _expandedDirs = <String>{''};
  List<CodeTabFlatNode> _flat = const [];

  String? _selectedFilePath;
  bool _loadingFile = false;
  String? _fileError;
  CodeTabFileContent? _fileContent;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _editOriginal = '';

  @override
  void initState() {
    super.initState();
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
    _editController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

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
      final raw = await _service.getProjectStorageStructure(widget.projectId);
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

  Future<void> _openFile(String relPath) async {
    if (_loadingFile && _selectedFilePath == relPath) return;

    setState(() {
      _selectedFilePath = relPath;
      _loadingFile = true;
      _fileError = null;
      _fileContent = null;
      _isEditing = false;
      _hasUnsavedChanges = false;
      _isSaving = false;
      _editOriginal = '';
      _editController.clear();
    });

    try {
      final raw = await _service.getProjectStorageFile(
        widget.projectId,
        relPath,
      );
      final content = CodeTabFileContent.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _fileContent = content;
        _editOriginal = content.content;
        _editController.text = content.content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFile = false;
        });
      }
    }
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

  void _enterEditMode() {
    final file = _fileContent;
    final path = _selectedFilePath;
    if (path == null || path.isEmpty) return;
    if (file == null || file.isBinary) return;
    if (_isEditing) return;
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
      _editOriginal = file.content;
      _editController.text = file.content;
    });
  }

  Future<void> _saveEdits() async {
    final path = _selectedFilePath;
    final file = _fileContent;
    if (path == null || path.isEmpty) return;
    if (file == null || file.isBinary) return;
    if (!_isEditing || !_hasUnsavedChanges) return;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final fileName = path.split('/').isEmpty ? 'file' : path.split('/').last;
      final result = await _service.syncFileToGitHub(
        widget.projectId,
        filePath: path,
        content: _editController.text,
        commitMessage: 'feat: update $fileName',
      );

      final commit = result['commit'];
      final commitSha = commit is Map<String, dynamic>
          ? commit['sha']?.toString()
          : null;
      final shortSha = (commitSha != null && commitSha.length >= 7)
          ? commitSha.substring(0, 7)
          : null;

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Saved',
        message: shortSha == null
            ? 'Saved successfully'
            : 'Saved (commit: $shortSha)',
      );

      setState(() {
        _fileContent = CodeTabFileContent(
          path: file.path,
          content: _editController.text,
          size: _editController.text.length,
          isBinary: false,
        );
        _editOriginal = _editController.text;
        _hasUnsavedChanges = false;
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Save failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _confirmLeaveEdit() async {
    if (!_isEditing || !_hasUnsavedChanges) return true;

    final result = await showDialog<CodeTabEditLeaveAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Save changes before leaving?'),
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
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
        _editController.text = _editOriginal;
      });
      return true;
    }
    await _saveEdits();
    return !_isEditing;
  }

  void _askAboutSelected() {
    final p = _selectedFilePath;
    if (p == null || p.isEmpty) return;
    widget.onAsk(
      'Please review the file "$p". Summarize what it does and propose improvements. '
      'If there are bugs or missing pieces, suggest concrete edits.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = _isMobile(context);
    final q = _searchController.text.trim();
    final hasSelection =
        _selectedFilePath != null && _selectedFilePath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 10),
              IconButton(
                onPressed: _loadingTree ? null : _loadTree,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 6),
              if (_isEditing) ...[
                IconButton(
                  onPressed: _isSaving || !_hasUnsavedChanges
                      ? null
                      : _saveEdits,
                  icon: _isSaving
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
          const SizedBox(height: 12),
          Expanded(
            child: mobile
                ? CodeTabTreePanel(
                    loading: _loadingTree,
                    error: _treeError,
                    searchQuery: q,
                    list: _flat,
                    selectedFilePath: _selectedFilePath,
                    expandedDirs: _expandedDirs,
                    onReload: _loadTree,
                    onToggleDir: _toggleDir,
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
                : Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: CodeTabTreePanel(
                          loading: _loadingTree,
                          error: _treeError,
                          searchQuery: q,
                          list: _flat,
                          selectedFilePath: _selectedFilePath,
                          expandedDirs: _expandedDirs,
                          onReload: _loadTree,
                          onToggleDir: _toggleDir,
                          onOpenFile: (p) async {
                            final ok = await _confirmLeaveEdit();
                            if (!ok) return;
                            await _openFile(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CodeTabFileViewer(
                          theme: theme,
                          filePath: _selectedFilePath,
                          loading: _loadingFile,
                          error: _fileError,
                          content: _fileContent,
                          isEditing: _isEditing,
                          editController: _editController,
                          hasUnsavedChanges: _hasUnsavedChanges,
                          saving: _isSaving,
                          onEnterEdit: _enterEditMode,
                          onCancelEdit: () async {
                            final ok = await _confirmLeaveEdit();
                            if (!ok) return;
                            setState(() {
                              _isEditing = false;
                              _hasUnsavedChanges = false;
                              _editController.text = _editOriginal;
                            });
                          },
                          onChange: (v) {
                            setState(() {
                              _hasUnsavedChanges = v != _editOriginal;
                            });
                          },
                          onSave: _saveEdits,
                          onCopy: _fileContent == null
                              ? null
                              : () async {
                                  final ctx = context;
                                  await Clipboard.setData(
                                    ClipboardData(text: _fileContent!.content),
                                  );
                                  if (!ctx.mounted) return;
                                  SnackBarHelper.showSuccess(
                                    ctx,
                                    title: 'Copied',
                                    message: 'File content copied',
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                          onAsk: _selectedFilePath == null
                              ? null
                              : _askAboutSelected,
                          projectId: widget.projectId,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
