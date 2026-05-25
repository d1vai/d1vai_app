import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
import '../project_chat_top_bar.dart';

class ProjectChatCodeTab extends StatefulWidget {
  final String? projectId;
  final ValueChanged<String> onAsk;
  final CodeTabTopBarController? topBarController;
  final String? initialLocalEntryPath;
  final bool initialLocalHybridMode;
  final VoidCallback? onDetachLocalWorkspace;

  const ProjectChatCodeTab({
    super.key,
    this.projectId,
    required this.onAsk,
    this.topBarController,
    this.initialLocalEntryPath,
    this.initialLocalHybridMode = true,
    this.onDetachLocalWorkspace,
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

  bool _loadingTree = false;
  String? _treeError;
  CodeTabFileNode? _root;
  final Set<String> _expandedDirs = <String>{''};
  List<CodeTabFlatNode> _flat = const [];
  double _desktopTreePaneWidth = 320;
  final Map<String, Timer> _syncTimers = <String, Timer>{};
  final Map<String, CodeTabFileContent> _localFileCache =
      <String, CodeTabFileContent>{};
  Timer? _searchDebounceTimer;
  String? _pendingInitialLocalOpenFilePath;
  bool _initialLocalFileOpened = false;
  bool _uploadingFiles = false;
  bool _treeDraggingFiles = false;
  int _treeOpenRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    _workbench = CodeWorkbenchController(service: _service);
    _workbenchListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _workbench.addListener(_workbenchListener);
    final initialLocal = _resolveInitialLocalAttachment(
      widget.initialLocalEntryPath,
    );
    if (initialLocal != null) {
      _workbench.attachLocalWorkspace(
        rootPath: initialLocal.rootPath,
        rootName: initialLocal.rootName,
        hybrid:
            widget.initialLocalHybridMode &&
            ((widget.projectId ?? '').trim().isNotEmpty),
      );
      _pendingInitialLocalOpenFilePath = initialLocal.openFilePath;
    }
    _loadTree();
    _searchListener = () {
      if (!mounted) return;
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        _rebuildFlatList();
      });
    };
    _searchController.addListener(_searchListener);
  }

  @override
  void dispose() {
    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();
    _searchDebounceTimer?.cancel();
    widget.topBarController?.reset();
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
    unawaited(
      _workbench.applyEditorPreferences(
        defaultWrap: prefs.defaultWrap,
        tabSize: prefs.tabSize,
      ),
    );
  }

  void _publishTopBarState() {
    final controller = widget.topBarController;
    if (controller == null) return;
    final activeEditor = _workbench.activeEditor;
    final hasSelection =
        _workbench.activePath != null && _workbench.activePath!.isNotEmpty;
    final syncState = activeEditor == null
        ? CodeTabTopBarSyncState.idle
        : switch (_workbench.syncStateFor(activeEditor.path)) {
            CodeWorkbenchSyncState.idle => CodeTabTopBarSyncState.idle,
            CodeWorkbenchSyncState.localSaved =>
              CodeTabTopBarSyncState.localSaved,
            CodeWorkbenchSyncState.queued => CodeTabTopBarSyncState.queued,
            CodeWorkbenchSyncState.syncingCloud =>
              CodeTabTopBarSyncState.syncingCloud,
            CodeWorkbenchSyncState.syncingGitHub =>
              CodeTabTopBarSyncState.syncingGitHub,
            CodeWorkbenchSyncState.synced => CodeTabTopBarSyncState.synced,
            CodeWorkbenchSyncState.failed => CodeTabTopBarSyncState.failed,
          };
    controller.update(
      searchController: _searchController,
      loadingTree: _loadingTree,
      hasSelection: hasSelection,
      activeEditing: activeEditor?.isEditing == true,
      activeSaving: activeEditor?.saving == true,
      activeHasUnsavedChanges: activeEditor?.hasUnsavedChanges == true,
      activeWrapEnabled: activeEditor?.wrapEnabled == true,
      activeFolded: activeEditor?.controller?.hasFoldedSections == true,
      supportsFoldAll: activeEditor?.controller?.supportsFoldAll == true,
      supportsFoldImports:
          activeEditor?.controller?.supportsFoldImports == true,
      supportsFoldHeader: activeEditor?.controller?.supportsFoldHeader == true,
      hasLocalWorkspace: _workbench.hasLocalWorkspace,
      uploadingFiles: _uploadingFiles,
      syncState: syncState,
      onReload: _loadingTree ? null : _loadTree,
      onUpload: _uploadingFiles ? null : _pickAndUploadFiles,
      onAsk: hasSelection ? _askAboutSelected : null,
      onFind: activeEditor?.isEditing == true
          ? activeEditor?.controller?.showSearch
          : null,
      onToggleWrap: activeEditor?.isEditing == true ? _toggleActiveWrap : null,
      onSave: activeEditor?.isEditing == true ? _saveActiveEditor : null,
      onFoldAll: activeEditor?.controller?.supportsFoldAll == true
          ? _foldAllActiveEditor
          : null,
      onUnfoldAll: activeEditor?.controller?.supportsFoldAll == true
          ? _unfoldAllActiveEditor
          : null,
      onFoldImports: activeEditor?.controller?.supportsFoldImports == true
          ? _foldActiveEditorImports
          : null,
      onFoldHeader: activeEditor?.controller?.supportsFoldHeader == true
          ? _foldActiveEditorHeader
          : null,
    );
  }

  void _toggleActiveWrap() {
    final path = _workbench.activeEditor?.path;
    if (path == null || path.isEmpty) return;
    unawaited(_workbench.toggleWrap(path));
  }

  void _saveActiveEditor() {
    final path = _workbench.activeEditor?.path;
    if (path == null || path.isEmpty) return;
    unawaited(_saveEditor(path));
  }

  void _foldAllActiveEditor() {
    _workbench.activeEditor?.controller?.foldAll();
  }

  void _unfoldAllActiveEditor() {
    _workbench.activeEditor?.controller?.unfoldAll();
  }

  void _foldActiveEditorImports() {
    _workbench.activeEditor?.controller?.foldImports();
  }

  void _foldActiveEditorHeader() {
    _workbench.activeEditor?.controller?.foldHeader();
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  bool _isMacDesktop(BuildContext context) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.macOS &&
      !_isMobile(context);

  bool get _allowLocalRename =>
      _workbench.hasLocalWorkspace && _workbench.localRootPath != null;

  Future<void> _loadTree() async {
    if (_loadingTree) return;
    final startedAt = DateTime.now();
    setState(() {
      _loadingTree = true;
      _treeError = null;
    });
    try {
      final cloudProjectId = (widget.projectId ?? '').trim();
      debugPrint(
        '[d1vai-open] code tree load start local=${_workbench.hasLocalWorkspace} '
        'root=${_workbench.localRootPath ?? '-'} '
        'project=${cloudProjectId.isEmpty ? 'none' : cloudProjectId}',
      );
      if (!_workbench.hasLocalWorkspace && cloudProjectId.isEmpty) {
        throw Exception('This workspace is not connected to a cloud project.');
      }
      final raw = _workbench.hasLocalWorkspace
          ? (await _localWorkspaceService.readTree(
              _workbench.localRootPath!,
            )).root
          : await _service.getProjectStorageStructure(cloudProjectId);
      if (!mounted) return;
      final node = CodeTabFileNode.fromJson(raw);
      final nextFlat = _buildFlatListFor(node, _searchController.text.trim());
      setState(() {
        _root = node;
        _flat = nextFlat;
        _loadingTree = false;
        _treeError = null;
      });
      debugPrint(
        '[d1vai-open] code tree load done local=${_workbench.hasLocalWorkspace} '
        'root=${_workbench.localRootPath ?? '-'} '
        'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
      await _maybeOpenInitialLocalFile();
    } catch (e) {
      debugPrint(
        '[d1vai-open] code tree load failed local=${_workbench.hasLocalWorkspace} '
        'root=${_workbench.localRootPath ?? '-'} '
        'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms '
        'error=$e',
      );
      if (!mounted) return;
      setState(() {
        _treeError = e.toString();
        _loadingTree = false;
      });
    }
  }

  Future<void> _maybeOpenInitialLocalFile() async {
    final pendingPath = _pendingInitialLocalOpenFilePath;
    if (_initialLocalFileOpened ||
        pendingPath == null ||
        pendingPath.trim().isEmpty) {
      return;
    }
    _initialLocalFileOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openDesktopFile(pendingPath, preview: false));
    });
  }

  void _rebuildFlatList() {
    final next = _buildFlatList();
    if (!mounted) return;
    if (_sameFlatList(_flat, next)) return;
    setState(() {
      _flat = next;
    });
  }

  List<CodeTabFlatNode> _buildFlatList() {
    return _buildFlatListFor(_root, _searchController.text.trim());
  }

  List<CodeTabFlatNode> _buildFlatListFor(
    CodeTabFileNode? root,
    String rawQuery,
  ) {
    if (root == null) return const [];

    final q = rawQuery.trim().toLowerCase();
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

  bool _sameFlatList(List<CodeTabFlatNode> a, List<CodeTabFlatNode> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].path != b[i].path || a[i].depth != b[i].depth) {
        return false;
      }
    }
    return true;
  }

  void _toggleDir(String dirPath) {
    _workbench.selectTreePath(dirPath);
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
        final editorController = active.controller;
        final latestText = editorController == null
            ? (active.content?.content ?? '')
            : await editorController.readText(refresh: true);
        await _localWorkspaceService.writeFile(
          _workbench.localRootPath!,
          path,
          latestText,
        );
        await _workbench.markLocalFileSaved(path, text: latestText);
        _cacheLocalFileContent(
          path,
          CodeTabFileContent(
            path: path,
            content: latestText,
            size: latestText.length,
            isBinary: false,
          ),
        );
        final cloudProjectId = (widget.projectId ?? '').trim();
        if (cloudProjectId.isNotEmpty) {
          _scheduleDeferredGitHubSync(path);
        }
        if (!mounted) return false;
        SnackBarHelper.showSuccess(
          context,
          title: 'Saved locally',
          message: cloudProjectId.isEmpty
              ? 'Local workspace updated.'
              : 'Local workspace updated. Syncing in the background.',
        );
        return true;
      }
      final cloudProjectId = (widget.projectId ?? '').trim();
      if (cloudProjectId.isEmpty) {
        throw Exception('This workspace is not connected to a cloud project.');
      }
      commitSha = await _workbench.saveEditor(cloudProjectId, path);
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
        final editorController = editor.controller;
        final latestText = editorController == null
            ? (editor.content?.content ?? '')
            : await editorController.readText(refresh: true);
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
    final projectId = (widget.projectId ?? '').trim();
    if (projectId.isEmpty) return;
    final editor = _workbench.editorForPath(path);
    if (editor == null || editor.content == null) return;
    try {
      final fileName = path.split('/').isEmpty ? 'file' : path.split('/').last;
      final editorController = editor.controller;
      final latestText = editorController == null
          ? editor.content!.content
          : await editorController.readText(refresh: true);
      final result = await _service.syncFileToGitHub(
        projectId,
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

  void _cancelPendingTreeOpen() {
    _treeOpenRequestSerial += 1;
  }

  int _beginTreeOpenRequest() {
    _treeOpenRequestSerial += 1;
    return _treeOpenRequestSerial;
  }

  bool _isTreeOpenRequestStale(int? token) {
    return token != null && token != _treeOpenRequestSerial;
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  Future<void> _editDesktopFileAfterFrame(String path) async {
    final token = _beginTreeOpenRequest();
    await _waitForNextFrame();
    if (!mounted || _isTreeOpenRequestStale(token)) return;
    await _openDesktopFile(path, preview: false, requestToken: token);
    if (!mounted || _isTreeOpenRequestStale(token)) return;
    final editor = _workbench.editorForPath(path);
    if (editor == null || editor.loading || editor.content == null) return;
    await _workbench.enterEditMode(path);
  }

  Future<void> _openDesktopFile(
    String path, {
    required bool preview,
    int? requestToken,
  }) async {
    if (_isTreeOpenRequestStale(requestToken)) return;
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
    if (_isTreeOpenRequestStale(requestToken)) return;

    if (_workbench.hasLocalWorkspace && _workbench.localRootPath != null) {
      final existing = _workbench.editorForPath(path);
      if (existing != null) {
        if (!preview) {
          _workbench.pinEditor(path);
        } else {
          _workbench.activateEditor(path);
        }
        return;
      }
      final cached = _localFileCache[path];
      if (cached != null) {
        await _workbench.openLocalFile(
          path,
          content: cached,
          preview: preview,
          wrapEnabled: prefs.defaultWrap,
          tabSize: prefs.tabSize,
        );
        return;
      }
      if (preview) {
        _workbench.reusePreviewEditor(path, wrapEnabled: prefs.defaultWrap);
      }
      final raw = await _localWorkspaceService.readFile(
        _workbench.localRootPath!,
        path,
      );
      if (_isTreeOpenRequestStale(requestToken)) return;
      final content = CodeTabFileContent(
        path: raw.path,
        content: raw.content,
        size: raw.size,
        isBinary: raw.isBinary,
      );
      _cacheLocalFileContent(path, content);
      await _workbench.openLocalFile(
        path,
        content: content,
        preview: preview,
        wrapEnabled: prefs.defaultWrap,
        tabSize: prefs.tabSize,
      );
      return;
    }

    final projectId = (widget.projectId ?? '').trim();
    if (projectId.isEmpty) {
      throw Exception('This workspace is not connected to a cloud project.');
    }
    if (_isTreeOpenRequestStale(requestToken)) return;
    await _workbench.openFile(
      projectId,
      path,
      preview: preview,
      wrapEnabled: prefs.defaultWrap,
      tabSize: prefs.tabSize,
    );
  }

  Future<void> _focusDesktopFile(String path) async {
    await _editDesktopFileAfterFrame(path);
  }

  void _cacheLocalFileContent(String path, CodeTabFileContent content) {
    _localFileCache[path] = content;
    if (_localFileCache.length <= 48) return;
    _localFileCache.remove(_localFileCache.keys.first);
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

  Future<void> _renameTreeEntry(String path, bool isDirectory) async {
    if (!_allowLocalRename) return;
    final rootPath = _workbench.localRootPath;
    if (rootPath == null || rootPath.isEmpty) return;
    final currentName = _lastSegment(path);
    final controller = TextEditingController(text: currentName);
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDirectory ? 'Rename folder' : 'Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmedName = (nextName ?? '').trim();
    if (trimmedName.isEmpty || trimmedName == currentName) return;

    try {
      final nextPath = await _localWorkspaceService.renameEntry(
        rootPath,
        path,
        newName: trimmedName,
        isDirectory: isDirectory,
      );
      _workbench.renamePathPrefix(path, nextPath);
      _renameCachedLocalPaths(path, nextPath);
      await _loadTree();
      _workbench.selectTreePath(nextPath);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: isDirectory ? 'Folder renamed' : 'File renamed',
        message: trimmedName,
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Rename failed',
        message: e.toString(),
      );
    }
  }

  void _renameCachedLocalPaths(String oldPath, String newPath) {
    bool matches(String candidate) =>
        candidate == oldPath || candidate.startsWith('$oldPath/');
    String rewrite(String candidate) {
      if (candidate == oldPath) return newPath;
      return '$newPath/${candidate.substring(oldPath.length + 1)}';
    }

    final next = <String, CodeTabFileContent>{};
    for (final entry in _localFileCache.entries) {
      final key = matches(entry.key) ? rewrite(entry.key) : entry.key;
      final value = matches(entry.key)
          ? CodeTabFileContent(
              path: rewrite(entry.value.path),
              content: entry.value.content,
              size: entry.value.size,
              isBinary: entry.value.isBinary,
            )
          : entry.value;
      next[key] = value;
    }
    _localFileCache
      ..clear()
      ..addAll(next);
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
    final editorController = active.controller;
    final latestText = editorController == null
        ? content.content
        : await editorController.readText(refresh: true);
    await Clipboard.setData(ClipboardData(text: latestText));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'File content copied',
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    if (_uploadingFiles) return;
    final cloudProjectId = (widget.projectId ?? '').trim();
    if (_workbench.hasLocalWorkspace || cloudProjectId.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Upload unavailable',
        message: 'File upload is available only for cloud project files.',
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((file) => file.bytes != null && (file.name).trim().isNotEmpty)
        .map(
          (file) =>
              (name: file.name.trim(), bytes: file.bytes!, mimeType: null),
        )
        .toList();
    if (files.isEmpty) return;
    await _uploadCloudFiles(files, targetDir: '');
  }

  Future<void> _uploadCloudFiles(
    List<({String name, Uint8List bytes, String? mimeType})> files, {
    required String targetDir,
  }) async {
    if (_uploadingFiles) return;
    final cloudProjectId = (widget.projectId ?? '').trim();
    if (cloudProjectId.isEmpty) return;
    setState(() {
      _uploadingFiles = true;
    });
    try {
      String? firstUploadedPath;
      for (final file in files) {
        final payload = await _service.uploadProjectStorageFile(
          cloudProjectId,
          fileBytes: file.bytes,
          fileName: file.name,
          targetDir: targetDir,
          contentType: file.mimeType,
        );
        final uploadedPath = (payload['data']?['path'] ?? payload['path'])
            ?.toString();
        if (firstUploadedPath == null &&
            uploadedPath != null &&
            uploadedPath.trim().isNotEmpty) {
          firstUploadedPath = uploadedPath.trim();
        }
      }
      await _loadTree();
      if (firstUploadedPath != null && mounted) {
        await _focusDesktopFile(firstUploadedPath);
      }
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: files.length == 1 ? 'Uploaded' : 'Uploads complete',
        message: files.length == 1
            ? 'File uploaded successfully.'
            : '${files.length} files uploaded successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Upload failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFiles = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = _isMobile(context);
    final compact = _isMacDesktop(context);
    final q = _searchController.text.trim();
    final activeEditor = _workbench.activeEditor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishTopBarState();
    });

    final content = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveActiveEditor,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveActiveEditor,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          unawaited(_loadTree());
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          unawaited(_loadTree());
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          _workbench.activeEditor?.controller?.showSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _workbench.activeEditor?.controller?.showSearch();
        },
      },
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(0, 8, 0, 0)
            : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: mobile
                  ? ValueListenableBuilder<String?>(
                      valueListenable: _workbench.selectedTreePathListenable,
                      builder: (context, selectedPath, _) {
                        return CodeTabTreePanel(
                          loading: _loadingTree,
                          error: _treeError,
                          searchQuery: q,
                          list: _flat,
                          selectedPath: selectedPath,
                          expandedDirs: _expandedDirs,
                          compact: false,
                          allowRename: _allowLocalRename,
                          onReload: _loadTree,
                          onToggleDir: _toggleDir,
                          onSelectItem: (path, _) {
                            _cancelPendingTreeOpen();
                            _workbench.selectTreePath(path);
                          },
                          onRenameItem: _renameTreeEntry,
                          onOpenFile: (p) async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CodeTabFileViewerPage(
                                  projectId: (widget.projectId ?? '').trim(),
                                  filePath: p,
                                  onAsk: (prompt) {
                                    widget.onAsk(prompt);
                                  },
                                ),
                              ),
                            );
                          },
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
                              child: ValueListenableBuilder<String?>(
                                valueListenable:
                                    _workbench.selectedTreePathListenable,
                                builder: (context, selectedPath, _) {
                                  return CodeTabTreePanel(
                                    loading: _loadingTree,
                                    error: _treeError,
                                    searchQuery: q,
                                    list: _flat,
                                    selectedPath: selectedPath,
                                    expandedDirs: _expandedDirs,
                                    compact: compact,
                                    allowRename: _allowLocalRename,
                                    onReload: _loadTree,
                                    onToggleDir: _toggleDir,
                                    onSelectItem: (path, _) {
                                      _cancelPendingTreeOpen();
                                      _workbench.selectTreePath(path);
                                    },
                                    onRenameItem: _renameTreeEntry,
                                    onOpenFile: (p) async {
                                      await _editDesktopFileAfterFrame(p);
                                    },
                                  );
                                },
                              ),
                            ),
                            _isMacDesktop(context)
                                ? _CodePaneResizeHandle(
                                    onDragDelta: (delta) {
                                      setState(() {
                                        _desktopTreePaneWidth =
                                            (_desktopTreePaneWidth + delta)
                                                .clamp(
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
                                        unawaited(
                                          _workbench.enterEditMode(
                                            activeEditor.path,
                                          ),
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
                                        _workbench.toggleWrap(
                                          activeEditor.path,
                                        ),
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
      ),
    );

    final canAcceptDrops =
        !kIsWeb &&
        !_workbench.hasLocalWorkspace &&
        (widget.projectId ?? '').trim().isNotEmpty;
    if (!canAcceptDrops) {
      return content;
    }

    return DropTarget(
      onDragEntered: (_) {
        if (!mounted || _uploadingFiles) return;
        setState(() {
          _treeDraggingFiles = true;
        });
      },
      onDragExited: (_) {
        if (!mounted) return;
        setState(() {
          _treeDraggingFiles = false;
        });
      },
      onDragDone: (detail) async {
        if (!mounted) return;
        final picked = <({String name, Uint8List bytes, String? mimeType})>[];
        for (final file in detail.files) {
          final path = file.path.trim();
          final name = file.name.trim();
          if (path.isEmpty || name.isEmpty) continue;
          final ioFile = File(path);
          if (!await ioFile.exists()) continue;
          final bytes = await ioFile.readAsBytes();
          picked.add((name: name, bytes: bytes, mimeType: null));
        }
        if (picked.isEmpty) {
          setState(() {
            _treeDraggingFiles = false;
          });
          return;
        }
        await _uploadCloudFiles(picked, targetDir: '');
      },
      child: Stack(
        children: [
          content,
          IgnorePointer(
            ignoring: !_treeDraggingFiles,
            child: AnimatedOpacity(
              opacity: _treeDraggingFiles ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Drop files to upload to project root'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ResolvedLocalWorkspaceAttachment? _resolveInitialLocalAttachment(
    String? entryPath,
  ) {
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows)) return null;
    final trimmed = (entryPath ?? '').trim();
    if (trimmed.isEmpty) return null;

    final entityType = FileSystemEntity.typeSync(trimmed, followLinks: true);
    if (entityType == FileSystemEntityType.directory) {
      return _ResolvedLocalWorkspaceAttachment(
        rootPath: _normalizePath(trimmed),
        rootName: _lastSegment(trimmed),
      );
    }
    if (entityType == FileSystemEntityType.file) {
      final normalizedFilePath = _normalizePath(trimmed);
      final file = File(normalizedFilePath);
      final rootPath = _normalizePath(file.parent.path);
      return _ResolvedLocalWorkspaceAttachment(
        rootPath: rootPath,
        rootName: _lastSegment(rootPath),
        openFilePath: _relativePath(rootPath: rootPath, filePath: trimmed),
      );
    }
    return null;
  }

  String _normalizePath(String path) =>
      path.trim().replaceAll(RegExp(r'[/\\]+$'), '');

  String _lastSegment(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return path;
    final parts = normalized.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? normalized : parts.last;
  }

  String _relativePath({required String rootPath, required String filePath}) {
    final normalizedRoot = _normalizePath(rootPath).replaceAll('\\', '/');
    final normalizedFile = _normalizePath(filePath).replaceAll('\\', '/');
    final prefix = '$normalizedRoot/';
    if (normalizedFile.startsWith(prefix)) {
      return normalizedFile.substring(prefix.length);
    }
    return _lastSegment(filePath);
  }
}

class _ResolvedLocalWorkspaceAttachment {
  final String rootPath;
  final String rootName;
  final String? openFilePath;

  const _ResolvedLocalWorkspaceAttachment({
    required this.rootPath,
    required this.rootName,
    this.openFilePath,
  });
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
