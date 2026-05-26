import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../services/d1vai_service.dart';
import 'app_code_editor_controller.dart';
import 'code_tab_models.dart';

class CodeWorkbenchEditorState {
  String path;
  AppCodeEditorController? controller;
  VoidCallback? controllerListener;
  Future<AppCodeEditorController>? controllerLoadFuture;
  CodeTabFileContent? content;
  String? error;
  bool loading;
  bool saving;
  bool isEditing;
  bool isPreview;
  bool wrapEnabled;
  int tabSize;
  String originalContent;
  bool lastKnownDirty;

  CodeWorkbenchEditorState({
    required this.path,
    required this.isPreview,
    this.content,
    this.error,
    this.loading = false,
    this.saving = false,
    this.isEditing = false,
    this.wrapEnabled = false,
    this.tabSize = 2,
    this.originalContent = '',
    this.lastKnownDirty = false,
  });

  bool get hasUnsavedChanges => controller?.hasUnsavedChanges ?? lastKnownDirty;
  bool get isBinary => content?.isBinary == true;
}

enum CodeWorkbenchSourceMode { cloudOnly, localAttached, hybrid }

enum CodeWorkbenchSyncState {
  idle,
  localSaved,
  queued,
  syncingCloud,
  syncingGitHub,
  synced,
  failed,
}

class CodeWorkbenchController extends ChangeNotifier {
  CodeWorkbenchController({required D1vaiService service}) : _service = service;

  final D1vaiService _service;
  final Map<String, CodeWorkbenchEditorState> _editorsByPath =
      <String, CodeWorkbenchEditorState>{};
  final List<String> _openPaths = <String>[];
  final ValueNotifier<String?> _selectedTreePathNotifier =
      ValueNotifier<String?>(null);

  String? _activePath;
  String? _previewPath;
  String? _selectedTreePath;
  CodeWorkbenchSourceMode _sourceMode = CodeWorkbenchSourceMode.cloudOnly;
  String? _localRootPath;
  String? _localRootName;
  final Set<String> _syncedPaths = <String>{};
  final Map<String, CodeWorkbenchSyncState> _syncStates =
      <String, CodeWorkbenchSyncState>{};
  final Map<String, DateTime> _queuedAt = <String, DateTime>{};

  List<CodeWorkbenchEditorState> get openEditors => _openPaths
      .map((path) => _editorsByPath[path])
      .whereType<CodeWorkbenchEditorState>()
      .toList(growable: false);

  String? get activePath => _activePath;
  String? get previewPath => _previewPath;
  String? get selectedTreePath => _selectedTreePath;
  ValueNotifier<String?> get selectedTreePathListenable =>
      _selectedTreePathNotifier;
  CodeWorkbenchSourceMode get sourceMode => _sourceMode;
  String? get localRootPath => _localRootPath;
  String? get localRootName => _localRootName;
  bool get hasLocalWorkspace =>
      (_localRootPath ?? '').trim().isNotEmpty &&
      _sourceMode != CodeWorkbenchSourceMode.cloudOnly;
  CodeWorkbenchEditorState? get activeEditor =>
      _activePath == null ? null : _editorsByPath[_activePath!];
  bool isPathSynced(String path) => _syncedPaths.contains(path);
  CodeWorkbenchSyncState syncStateFor(String path) =>
      _syncStates[path] ?? CodeWorkbenchSyncState.idle;

  void selectTreePath(String? path) {
    _setSelectedTreePath(path);
  }

  bool _setSelectedTreePath(String? path) {
    if (_selectedTreePath == path) return false;
    _selectedTreePath = path;
    _selectedTreePathNotifier.value = path;
    return true;
  }

  CodeWorkbenchEditorState? editorForPath(String path) => _editorsByPath[path];

  bool canReplacePreviewWith(String path) {
    final previewPath = _previewPath;
    if (previewPath == null || previewPath == path) return true;
    final preview = _editorsByPath[previewPath];
    if (preview == null) return true;
    return !preview.hasUnsavedChanges && !preview.saving;
  }

  bool hasUnsavedChanges(String path) =>
      _editorsByPath[path]?.hasUnsavedChanges == true;

  bool isPreviewOnly(String path) => _previewPath == path;

  CodeWorkbenchEditorState _createEditorShell(
    String path, {
    required bool preview,
    required bool wrapEnabled,
    required int tabSize,
    required bool loading,
  }) {
    if (preview) {
      final oldPreviewPath = _previewPath;
      if (oldPreviewPath != null && oldPreviewPath != path) {
        _removeEditor(oldPreviewPath);
      }
      _previewPath = path;
    }

    final editor = CodeWorkbenchEditorState(
      path: path,
      isPreview: preview,
      loading: loading,
      wrapEnabled: wrapEnabled,
      tabSize: tabSize,
    );
    _editorsByPath[path] = editor;
    _openPaths.add(path);
    _activePath = path;
    return editor;
  }

  Future<AppCodeEditorController> _ensureEditorController(
    CodeWorkbenchEditorState editor,
  ) {
    final existing = editor.controller;
    if (existing != null) {
      return Future<AppCodeEditorController>.value(existing);
    }

    final pending = editor.controllerLoadFuture;
    if (pending != null) {
      return pending;
    }

    final future = () async {
      final controller = await AppCodeEditorController.create(
        filePath: editor.path,
        tabSize: editor.tabSize,
        wrapEnabled: editor.wrapEnabled,
      );
      if (!_editorsByPath.containsKey(editor.path)) {
        controller.dispose();
        throw StateError('Editor was closed before controller initialization.');
      }
      editor.controller = controller;
      editor.controllerListener = () => _handleControllerChanged(editor);
      controller.addListener(editor.controllerListener!);

      final content = editor.content;
      final initialText = content == null || content.isBinary
          ? ''
          : content.content;
      await controller.setLanguageForPath(editor.path);
      await controller.setText(initialText, markSaved: true);
      editor.lastKnownDirty = false;
      return controller;
    }();

    editor.controllerLoadFuture = future;
    return future.whenComplete(() {
      editor.controllerLoadFuture = null;
    });
  }

  void attachLocalWorkspace({
    required String rootPath,
    required String rootName,
    bool hybrid = true,
  }) {
    _localRootPath = rootPath;
    _localRootName = rootName;
    _sourceMode = hybrid
        ? CodeWorkbenchSourceMode.hybrid
        : CodeWorkbenchSourceMode.localAttached;
    notifyListeners();
  }

  void clearLocalWorkspace() {
    _localRootPath = null;
    _localRootName = null;
    _sourceMode = CodeWorkbenchSourceMode.cloudOnly;
    notifyListeners();
  }

  void markPathQueued(String path) {
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.queued;
    _queuedAt[path] = DateTime.now();
    notifyListeners();
  }

  void markPathSynced(String path) {
    _syncedPaths.add(path);
    _syncStates[path] = CodeWorkbenchSyncState.synced;
    _queuedAt.remove(path);
    notifyListeners();
  }

  void markPathDirty(String path) {
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.failed;
    _queuedAt.remove(path);
    notifyListeners();
  }

  void renamePathPrefix(String oldPath, String newPath) {
    final normalizedOld = oldPath.trim();
    final normalizedNew = newPath.trim();
    if (normalizedOld.isEmpty ||
        normalizedNew.isEmpty ||
        normalizedOld == normalizedNew) {
      return;
    }

    bool matches(String candidate) =>
        candidate == normalizedOld || candidate.startsWith('$normalizedOld/');

    String rewrite(String candidate) {
      if (candidate == normalizedOld) return normalizedNew;
      return '$normalizedNew/${candidate.substring(normalizedOld.length + 1)}';
    }

    final affected = _editorsByPath.keys.where(matches).toList(growable: false);
    for (final oldKey in affected) {
      final editor = _editorsByPath.remove(oldKey);
      if (editor == null) continue;
      final nextKey = rewrite(oldKey);
      editor.path = nextKey;
      _editorsByPath[nextKey] = editor;
    }

    for (var i = 0; i < _openPaths.length; i += 1) {
      if (matches(_openPaths[i])) {
        _openPaths[i] = rewrite(_openPaths[i]);
      }
    }

    if (_activePath != null && matches(_activePath!)) {
      _activePath = rewrite(_activePath!);
    }
    if (_previewPath != null && matches(_previewPath!)) {
      _previewPath = rewrite(_previewPath!);
    }
    if (_selectedTreePath != null && matches(_selectedTreePath!)) {
      _setSelectedTreePath(rewrite(_selectedTreePath!));
    }

    void rewriteStateMap<T>(Map<String, T> source) {
      final next = <String, T>{};
      for (final entry in source.entries) {
        next[matches(entry.key) ? rewrite(entry.key) : entry.key] = entry.value;
      }
      source
        ..clear()
        ..addAll(next);
    }

    rewriteStateMap(_syncStates);
    rewriteStateMap(_queuedAt);

    final nextSynced = _syncedPaths
        .map((path) => matches(path) ? rewrite(path) : path)
        .toSet();
    _syncedPaths
      ..clear()
      ..addAll(nextSynced);

    notifyListeners();
  }

  Future<void> openFile(
    String projectId,
    String path, {
    bool preview = true,
    bool openInEditMode = false,
    bool wrapEnabled = false,
    int tabSize = 2,
  }) async {
    selectTreePath(path);

    final existing = _editorsByPath[path];
    if (existing != null) {
      if (!preview || openInEditMode) {
        existing.isPreview = false;
        if (_previewPath == path) {
          _previewPath = null;
        }
      }
      if (openInEditMode && !existing.isBinary) {
        await _ensureEditorController(existing);
        existing.isEditing = true;
      }
      _activePath = path;
      notifyListeners();
      return;
    }

    final editor = _createEditorShell(
      path,
      preview: preview,
      wrapEnabled: wrapEnabled,
      tabSize: tabSize,
      loading: true,
    );
    notifyListeners();

    try {
      final raw = await _service.getProjectStorageFile(projectId, path);
      final content = CodeTabFileContent.fromJson(raw);
      editor.content = content;
      editor.error = null;
      editor.loading = false;
      editor.originalContent = content.content;
      final controller = editor.controller;
      if (controller != null) {
        await controller.setLanguageForPath(path);
        await controller.setText(content.content, markSaved: true);
      }
      if (openInEditMode && !content.isBinary) {
        await _ensureEditorController(editor);
        editor.isEditing = true;
        editor.isPreview = false;
        if (_previewPath == path) {
          _previewPath = null;
        }
      }
      editor.lastKnownDirty = false;
    } catch (e) {
      editor.error = e.toString();
      editor.loading = false;
      editor.content = null;
    }

    notifyListeners();
  }

  Future<void> openLocalFile(
    String path, {
    required CodeTabFileContent content,
    bool preview = true,
    bool openInEditMode = false,
    bool wrapEnabled = false,
    int tabSize = 2,
  }) async {
    selectTreePath(path);

    final existing = _editorsByPath[path];
    if (existing != null) {
      setFileContent(path, content: content, keepEditing: existing.isEditing);
      if (!preview || openInEditMode) {
        existing.isPreview = false;
        if (_previewPath == path) {
          _previewPath = null;
        }
      }
      if (openInEditMode && !content.isBinary) {
        await _ensureEditorController(existing);
        existing.isEditing = true;
      }
      _activePath = path;
      notifyListeners();
      return;
    }

    final editor = _createEditorShell(
      path,
      preview: preview,
      wrapEnabled: wrapEnabled,
      tabSize: tabSize,
      loading: false,
    );
    editor.content = content;
    editor.error = null;
    editor.loading = false;
    editor.originalContent = content.isBinary ? '' : content.content;
    _syncedPaths.add(path);
    _syncStates[path] = CodeWorkbenchSyncState.synced;
    _queuedAt.remove(path);
    editor.lastKnownDirty = false;
    if (openInEditMode && !content.isBinary) {
      await _ensureEditorController(editor);
      editor.isEditing = true;
      editor.isPreview = false;
      if (_previewPath == path) {
        _previewPath = null;
      }
    }
    notifyListeners();
  }

  void activateEditor(String path) {
    _setSelectedTreePath(path);
    if (_activePath == path) return;
    _activePath = path;
    notifyListeners();
  }

  void pinEditor(String path) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    _setSelectedTreePath(path);
    editor.isPreview = false;
    if (_previewPath == path) {
      _previewPath = null;
    }
    _activePath = path;
    notifyListeners();
  }

  Future<void> enterEditMode(String path) async {
    final editor = _editorsByPath[path];
    if (editor == null || editor.content == null || editor.isBinary) return;
    await _ensureEditorController(editor);
    editor.isEditing = true;
    editor.isPreview = false;
    if (_previewPath == path) {
      _previewPath = null;
    }
    _activePath = path;
    notifyListeners();
  }

  Future<void> toggleWrap(String path) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    editor.wrapEnabled = !editor.wrapEnabled;
    final controller = editor.controller;
    if (controller != null) {
      await controller.setWrapEnabled(editor.wrapEnabled);
    }
    notifyListeners();
  }

  Future<void> applyEditorPreferences({
    required bool defaultWrap,
    required int tabSize,
  }) async {
    for (final editor in _editorsByPath.values) {
      editor.wrapEnabled = defaultWrap;
      editor.tabSize = tabSize;
      final controller = editor.controller;
      if (controller == null) continue;
      await controller.setTabSpaces(tabSize);
      await controller.setWrapEnabled(defaultWrap);
    }
    notifyListeners();
  }

  Future<void> cancelEdit(String path) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    final controller = await _ensureEditorController(editor);
    await controller.setText(editor.originalContent, markSaved: true);
    editor.isEditing = false;
    if (_syncedPaths.contains(path)) {
      _syncStates[path] = CodeWorkbenchSyncState.synced;
    } else {
      _syncStates[path] = CodeWorkbenchSyncState.idle;
    }
    editor.lastKnownDirty = editor.hasUnsavedChanges;
    notifyListeners();
  }

  Future<void> updateText(String path, String text) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    final controller = await _ensureEditorController(editor);
    final current = await controller.readText();
    if (current == text) return;
    await controller.setText(text);
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.queued;
  }

  void setFileContent(
    String path, {
    required CodeTabFileContent content,
    bool keepEditing = false,
  }) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    editor.content = content;
    editor.error = null;
    editor.loading = false;
    editor.originalContent = content.isBinary ? '' : content.content;
    final controller = editor.controller;
    if (controller != null) {
      unawaited(controller.setLanguageForPath(path));
      unawaited(
        controller.setText(
          content.isBinary ? '' : content.content,
          markSaved: true,
        ),
      );
    }
    editor.isEditing = keepEditing && !content.isBinary;
    if (!keepEditing) {
      _syncedPaths.add(path);
      _syncStates[path] = CodeWorkbenchSyncState.synced;
      _queuedAt.remove(path);
      editor.lastKnownDirty = false;
    }
    notifyListeners();
  }

  Future<void> markLocalFileSaved(String path, {required String text}) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    final previous = editor.content;
    editor.content = CodeTabFileContent(
      path: previous?.path ?? path,
      content: text,
      size: text.length,
      isBinary: false,
    );
    editor.originalContent = text;
    editor.isEditing = false;
    final controller = await _ensureEditorController(editor);
    await controller.markSaved();
    editor.lastKnownDirty = false;
    markPathLocalSaved(path);
  }

  void markPathLocalSaved(String path) {
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.localSaved;
    _queuedAt[path] = DateTime.now();
    notifyListeners();
  }

  bool reusePreviewEditor(String nextPath, {required bool wrapEnabled}) {
    final previewPath = _previewPath;
    if (previewPath == null || previewPath == nextPath) return false;
    final editor = _editorsByPath.remove(previewPath);
    if (editor == null) return false;

    final openIndex = _openPaths.indexOf(previewPath);
    if (openIndex >= 0) {
      _openPaths[openIndex] = nextPath;
    } else {
      _openPaths.add(nextPath);
    }

    editor.path = nextPath;
    editor.content = null;
    editor.error = null;
    editor.loading = true;
    editor.saving = false;
    editor.isEditing = false;
    editor.isPreview = true;
    editor.wrapEnabled = wrapEnabled;
    editor.originalContent = '';
    editor.lastKnownDirty = false;
    _editorsByPath[nextPath] = editor;
    _activePath = nextPath;
    _previewPath = nextPath;
    _syncedPaths.remove(previewPath);
    _syncStates.remove(previewPath);
    _queuedAt.remove(previewPath);
    _syncedPaths.remove(nextPath);
    _syncStates.remove(nextPath);
    _queuedAt.remove(nextPath);
    notifyListeners();
    return true;
  }

  void markPathSyncingGitHub(String path) {
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.syncingGitHub;
    _queuedAt[path] = DateTime.now();
    notifyListeners();
  }

  Future<String?> saveEditor(String projectId, String path) async {
    final editor = _editorsByPath[path];
    final content = editor?.content;
    if (editor == null || content == null || content.isBinary) return null;
    if (!editor.isEditing || !editor.hasUnsavedChanges || editor.saving) {
      return null;
    }

    editor.saving = true;
    markPathLocalSaved(path);
    markPathQueued(path);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      markPathSyncingGitHub(path);
      final fileName = path.split('/').isEmpty ? 'file' : path.split('/').last;
      final controller = await _ensureEditorController(editor);
      final latestText = await controller.readText(refresh: true);
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
      editor.content = CodeTabFileContent(
        path: content.path,
        content: latestText,
        size: latestText.length,
        isBinary: false,
      );
      editor.originalContent = latestText;
      await controller.markSaved();
      editor.isEditing = false;
      _syncedPaths.add(path);
      _syncStates[path] = CodeWorkbenchSyncState.synced;
      _queuedAt.remove(path);
      editor.lastKnownDirty = false;
      return commitSha;
    } catch (_) {
      _syncedPaths.remove(path);
      _syncStates[path] = CodeWorkbenchSyncState.failed;
      _queuedAt.remove(path);
      rethrow;
    } finally {
      editor.saving = false;
      notifyListeners();
    }
  }

  Future<void> discardChanges(String path) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    final controller = await _ensureEditorController(editor);
    await controller.setText(editor.originalContent, markSaved: true);
    editor.isEditing = false;
    _syncedPaths.add(path);
    _syncStates[path] = CodeWorkbenchSyncState.synced;
    _queuedAt.remove(path);
    editor.lastKnownDirty = false;
    notifyListeners();
  }

  Duration? queuedDurationFor(String path) {
    final startedAt = _queuedAt[path];
    if (startedAt == null) return null;
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }

  void closeEditor(String path) {
    final wasActive = _activePath == path;
    final wasPreview = _previewPath == path;
    _removeEditor(path);
    if (wasPreview) {
      _previewPath = null;
    }
    if (wasActive) {
      _activePath = _openPaths.isEmpty ? null : _openPaths.last;
      _setSelectedTreePath(_activePath);
    }
    notifyListeners();
  }

  void _removeEditor(String path) {
    final editor = _editorsByPath.remove(path);
    _openPaths.remove(path);
    final controller = editor?.controller;
    final listener = editor?.controllerListener;
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    controller?.dispose();
  }

  void _handleControllerChanged(CodeWorkbenchEditorState editor) {
    if (!_editorsByPath.containsKey(editor.path)) return;
    final dirty = editor.hasUnsavedChanges;
    if (dirty == editor.lastKnownDirty) return;
    editor.lastKnownDirty = dirty;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final editor in _editorsByPath.values) {
      editor.controller?.dispose();
    }
    _editorsByPath.clear();
    _openPaths.clear();
    _selectedTreePathNotifier.dispose();
    super.dispose();
  }
}
