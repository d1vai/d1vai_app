import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../../../services/d1vai_service.dart';
import '../../snackbar_helper.dart';
import '../file_type_visual.dart';

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
  _FileNode? _root;
  final Set<String> _expandedDirs = <String>{''};

  String? _selectedFilePath;
  bool _loadingFile = false;
  String? _fileError;
  _FileContent? _fileContent;
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
      setState(() {});
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
      _expandedDirs
        ..clear()
        ..add('');
    });
    try {
      final raw = await _service.getProjectStorageStructure(widget.projectId);
      if (!mounted) return;
      final node = _FileNode.fromJson(raw);
      setState(() {
        _root = node;
      });
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
      final content = _FileContent.fromJson(raw);
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
        _fileContent = _FileContent(
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

    final result = await showDialog<_EditLeaveAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Save changes before leaving?'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_EditLeaveAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_EditLeaveAction.discard),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_EditLeaveAction.save),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result == _EditLeaveAction.cancel) return false;
    if (result == _EditLeaveAction.discard) {
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

  List<_FlatNode> _flatten() {
    final root = _root;
    if (root == null) return const [];

    final q = _searchController.text.trim().toLowerCase();
    final out = <_FlatNode>[];

    void walk(_FileNode node, String parentPath, int depth) {
      final rel = parentPath.isEmpty ? node.name : '$parentPath/${node.name}';
      final match =
          q.isEmpty ||
          node.name.toLowerCase().contains(q) ||
          rel.toLowerCase().contains(q);
      if (match) {
        out.add(_FlatNode(node: node, path: rel, depth: depth));
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

    // The server returns a root node representing the project itself.
    // Treat it as container and only render its children at the top level.
    final top = root.children;
    if (top != null) {
      for (final c in top) {
        walk(c, '', 0);
      }
    }

    // In search mode, keep directories but sort by path length then path.
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

    final list = _flatten();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          Expanded(
            child: mobile
                ? _buildMobile(theme, list)
                : _buildDesktop(theme, list),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final hasSelection =
        _selectedFilePath != null && _selectedFilePath!.isNotEmpty;
    return Row(
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
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              suffixIcon: _searchController.text.trim().isEmpty
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
            onPressed: _isSaving || !_hasUnsavedChanges ? null : _saveEdits,
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
    );
  }

  Widget _buildMobile(ThemeData theme, List<_FlatNode> list) {
    return Column(
      children: [
        Expanded(
          child: _buildTreePanel(
            theme,
            list,
            onOpenFile: (p) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FileViewerPage(
                    projectId: widget.projectId,
                    filePath: p,
                    onAsk: (prompt) {
                      widget.onAsk(prompt);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(ThemeData theme, List<_FlatNode> list) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _buildTreePanel(
            theme,
            list,
            onOpenFile: (p) async {
              final ok = await _confirmLeaveEdit();
              if (!ok) return;
              await _openFile(p);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FileViewer(
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
                    await Clipboard.setData(
                      ClipboardData(text: _fileContent!.content),
                    );
                    if (!mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Copied',
                      message: 'File content copied',
                      duration: const Duration(seconds: 2),
                    );
                  },
            onAsk: _selectedFilePath == null ? null : _askAboutSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildTreePanel(
    ThemeData theme,
    List<_FlatNode> list, {
    required Future<void> Function(String path) onOpenFile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _loadingTree
          ? const Center(child: CircularProgressIndicator())
          : _treeError != null
          ? _ErrorView(
              title: 'Failed to load files',
              message: _treeError!,
              onRetry: _loadTree,
            )
          : list.isEmpty
          ? _EmptyView(
              text: _searchController.text.trim().isEmpty
                  ? 'No files found'
                  : 'No matches',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemBuilder: (context, index) {
                final item = list[index];
                final isDir = item.node.isDirectory;
                final path = item.path;
                final selected = !isDir && path == _selectedFilePath;
                final dirExpanded = isDir && _expandedDirs.contains(path);

                return InkWell(
                  onTap: () async {
                    if (isDir) {
                      _toggleDir(path);
                      return;
                    }
                    await onOpenFile(path);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 10.0 * item.depth),
                        Icon(
                          isDir
                              ? (dirExpanded ? Icons.folder_open : Icons.folder)
                              : _iconForFile(item.node.name),
                          size: 18,
                          color: isDir
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isDir)
                          Icon(
                            dirExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemCount: list.length,
            ),
    );
  }

  IconData _iconForFile(String name) {
    return fileTypeVisual(Theme.of(context), name).icon;
  }
}

class _FileNode {
  final String name;
  final bool isDirectory;
  final int? size;
  final List<_FileNode>? children;

  const _FileNode({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.children,
  });

  factory _FileNode.fromJson(Map<String, dynamic> json) {
    return _FileNode(
      name: (json['name'] ?? '').toString(),
      isDirectory: json['is_directory'] == true,
      size: (json['size'] is int) ? json['size'] as int : null,
      children: (json['children'] is List)
          ? (json['children'] as List)
                .whereType<Map>()
                .map((e) => _FileNode.fromJson(e.cast<String, dynamic>()))
                .toList()
          : null,
    );
  }
}

class _FlatNode {
  final _FileNode node;
  final String path; // relative path within project
  final int depth;

  const _FlatNode({
    required this.node,
    required this.path,
    required this.depth,
  });
}

class _FileContent {
  final String path;
  final String content;
  final int size;
  final bool isBinary;

  const _FileContent({
    required this.path,
    required this.content,
    required this.size,
    required this.isBinary,
  });

  factory _FileContent.fromJson(Map<String, dynamic> json) {
    return _FileContent(
      path: (json['path'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      size: (json['size'] is int) ? json['size'] as int : 0,
      isBinary: json['is_binary'] == true,
    );
  }
}

class _FileViewer extends StatelessWidget {
  final ThemeData theme;
  final String? filePath;
  final bool loading;
  final String? error;
  final _FileContent? content;
  final bool isEditing;
  final TextEditingController editController;
  final bool hasUnsavedChanges;
  final bool saving;
  final VoidCallback? onEnterEdit;
  final VoidCallback? onCancelEdit;
  final ValueChanged<String>? onChange;
  final VoidCallback? onSave;
  final VoidCallback? onCopy;
  final VoidCallback? onAsk;

  const _FileViewer({
    required this.theme,
    required this.filePath,
    required this.loading,
    required this.error,
    required this.content,
    required this.isEditing,
    required this.editController,
    required this.hasUnsavedChanges,
    required this.saving,
    required this.onEnterEdit,
    required this.onCancelEdit,
    required this.onChange,
    required this.onSave,
    required this.onCopy,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final p = filePath;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p == null || p.isEmpty ? 'Select a file' : p,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onAsk,
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Ask AI',
                ),
                if (p != null &&
                    p.isNotEmpty &&
                    content != null &&
                    !content!.isBinary)
                  IconButton(
                    onPressed: isEditing
                        ? (saving || !hasUnsavedChanges ? null : onSave)
                        : onEnterEdit,
                    icon: isEditing
                        ? (saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save))
                        : const Icon(Icons.edit),
                    tooltip: isEditing ? 'Save' : 'Edit',
                  ),
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? _ErrorView(
                    title: 'Failed to open file',
                    message: error!,
                    onRetry: null,
                  )
                : content == null
                ? const _EmptyView(text: 'Pick a file from the tree')
                : GestureDetector(
                    onDoubleTap: onEnterEdit,
                    child: isEditing
                        ? _CodeEditor(
                            controller: editController,
                            onChanged: onChange,
                            onCancel: onCancelEdit,
                            dirty: hasUnsavedChanges,
                          )
                        : _CodeBlock(
                            filePath: p,
                            text: content!.content,
                            isBinary: content!.isBinary,
                            sizeBytes: content!.size,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CodeEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final bool dirty;

  const _CodeEditor({
    required this.controller,
    required this.onChanged,
    required this.onCancel,
    required this.dirty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(
                dirty ? Icons.circle : Icons.check_circle,
                size: 14,
                color: dirty ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirty ? 'Editing (unsaved changes)' : 'Editing',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _FileViewerPage extends StatefulWidget {
  final String projectId;
  final String filePath;
  final ValueChanged<String> onAsk;

  const _FileViewerPage({
    required this.projectId,
    required this.filePath,
    required this.onAsk,
  });

  @override
  State<_FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<_FileViewerPage> {
  final D1vaiService _service = D1vaiService();
  bool _loading = false;
  String? _error;
  _FileContent? _content;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _editOriginal = '';
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _content = null;
      _isEditing = false;
      _hasUnsavedChanges = false;
      _isSaving = false;
      _editOriginal = '';
      _editController.clear();
    });
    try {
      final raw = await _service.getProjectStorageFile(
        widget.projectId,
        widget.filePath,
      );
      if (!mounted) return;
      setState(() {
        _content = _FileContent.fromJson(raw);
        _editOriginal = _content!.content;
        _editController.text = _content!.content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _enterEdit() {
    final c = _content;
    if (c == null || c.isBinary) return;
    if (_isEditing) return;
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
      _editOriginal = c.content;
      _editController.text = c.content;
    });
  }

  Future<void> _save() async {
    final c = _content;
    if (c == null || c.isBinary) return;
    if (!_isEditing || !_hasUnsavedChanges) return;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });
    try {
      final fileName = widget.filePath.split('/').isEmpty
          ? 'file'
          : widget.filePath.split('/').last;
      final result = await _service.syncFileToGitHub(
        widget.projectId,
        filePath: widget.filePath,
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
        _content = _FileContent(
          path: c.path,
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

  Future<bool> _confirmLeave() async {
    if (!_isEditing || !_hasUnsavedChanges) return true;
    final result = await showDialog<_EditLeaveAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Save changes before leaving?'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_EditLeaveAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_EditLeaveAction.discard),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_EditLeaveAction.save),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null || result == _EditLeaveAction.cancel) return false;
    if (result == _EditLeaveAction.discard) {
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
        _editController.text = _editOriginal;
      });
      return true;
    }
    await _save();
    return !_isEditing;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _content;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () {
              widget.onAsk(
                'Please review the file "${widget.filePath}". Summarize what it does and propose improvements. '
                'If there are bugs or missing pieces, suggest concrete edits.',
              );
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Ask AI',
          ),
          if (content != null && !content.isBinary)
            IconButton(
              onPressed: _isEditing
                  ? (_isSaving || !_hasUnsavedChanges ? null : _save)
                  : _enterEdit,
              icon: _isEditing
                  ? (_isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save))
                  : const Icon(Icons.edit),
              tooltip: _isEditing ? 'Save' : 'Edit',
            ),
          IconButton(
            onPressed: content == null
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: content.content),
                    );
                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Copied',
                      message: 'File content copied',
                      duration: const Duration(seconds: 2),
                    );
                  },
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: PopScope(
            canPop: !(_isEditing && _hasUnsavedChanges),
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final ok = await _confirmLeave();
              if (!ok) return;
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(
                    title: 'Failed to open file',
                    message: _error!,
                    onRetry: _load,
                  )
                : content == null
                ? const _EmptyView(text: 'No content')
                : GestureDetector(
                    onDoubleTap: _enterEdit,
                    child: _isEditing
                        ? _CodeEditor(
                            controller: _editController,
                            onChanged: (v) {
                              setState(() {
                                _hasUnsavedChanges = v != _editOriginal;
                              });
                            },
                            onCancel: () async {
                              final ok = await _confirmLeave();
                              if (!ok) return;
                              setState(() {
                                _isEditing = false;
                                _hasUnsavedChanges = false;
                                _editController.text = _editOriginal;
                              });
                            },
                            dirty: _hasUnsavedChanges,
                          )
                        : _CodeBlock(
                            filePath: widget.filePath,
                            text: content.content,
                            isBinary: content.isBinary,
                            sizeBytes: content.size,
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String? filePath;
  final String text;
  final bool isBinary;
  final int sizeBytes;

  const _CodeBlock({
    this.filePath,
    required this.text,
    required this.isBinary,
    required this.sizeBytes,
  });

  String? _languageForPath(String? path) {
    if (path == null) return null;
    final p = path.toLowerCase();

    if (p.endsWith('.dart')) return 'dart';
    if (p.endsWith('.ts') || p.endsWith('.tsx')) return 'typescript';
    if (p.endsWith('.js') || p.endsWith('.jsx')) return 'javascript';
    if (p.endsWith('.json')) return 'json';
    if (p.endsWith('.md') || p.endsWith('.markdown')) return 'markdown';
    if (p.endsWith('.css')) return 'css';
    if (p.endsWith('.scss')) return 'scss';
    if (p.endsWith('.html') || p.endsWith('.htm')) return 'xml';
    if (p.endsWith('.yml') || p.endsWith('.yaml')) return 'yaml';
    if (p.endsWith('.py')) return 'python';
    if (p.endsWith('.rs')) return 'rust';
    if (p.endsWith('.sql')) return 'sql';
    if (p.endsWith('.sh') || p.endsWith('.bash')) return 'bash';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightLanguage = _languageForPath(filePath);
    final isDark = theme.brightness == Brightness.dark;
    final codeTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      height: 1.3,
    );

    // Avoid heavy highlighting on very large files (keeps scrolling smooth).
    final enableHighlight =
        !isBinary && highlightLanguage != null && text.length <= 200000;
    final highlightTheme = Map<String, TextStyle>.from(
      isDark ? atomOneDarkTheme : atomOneLightTheme,
    );
    final root = highlightTheme['root'];
    highlightTheme['root'] = (root ?? const TextStyle()).copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBinary)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'Binary file ($sizeBytes bytes). Showing placeholder content.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          if (isBinary) const SizedBox(height: 10),
          if (enableHighlight)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                text,
                language: highlightLanguage,
                theme: highlightTheme,
                padding: EdgeInsets.zero,
                textStyle: codeTextStyle,
              ),
            )
          else
            SelectableText(text, style: codeTextStyle),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String text;
  const _EmptyView({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _EditLeaveAction { save, discard, cancel }
