import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../providers/editor_preferences_provider.dart';
import '../../../../services/d1vai_service.dart';
import 'app_code_editor_controller.dart';
import 'code_tab_models.dart';

class CodeWorkbenchEditorState {
  final String path;
  final AppCodeEditorController controller;
  final VoidCallback controllerListener;
  CodeTabFileContent? content;
  String? error;
  bool loading;
  bool saving;
  bool isEditing;
  bool isPreview;
  bool wrapEnabled;
  String originalContent;
  bool lastKnownDirty;

  CodeWorkbenchEditorState({
    required this.path,
    required this.controller,
    required this.controllerListener,
    required this.isPreview,
    this.content,
    this.error,
    this.loading = false,
    this.saving = false,
    this.isEditing = false,
    this.wrapEnabled = false,
    this.originalContent = '',
    this.lastKnownDirty = false,
  });

  bool get hasUnsavedChanges => controller.hasUnsavedChanges;
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
    if (_selectedTreePath == path) return;
    _selectedTreePath = path;
    notifyListeners();
  }

  CodeWorkbenchEditorState? editorForPath(String path) => _editorsByPath[path];

  bool canReplacePreviewWith(String path) {
    final previewPath = _previewPath;
    if (previewPath == null || previewPath == path) return true;
    final preview = _editorsByPath[previewPath];
    if (preview == null) return true;
    return !preview.hasUnsavedChanges && !preview.isEditing && !preview.saving;
  }

  bool hasUnsavedChanges(String path) =>
      _editorsByPath[path]?.hasUnsavedChanges == true;

  bool isPreviewOnly(String path) => _previewPath == path;

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

  Future<void> openFile(
    String projectId,
    String path, {
    bool preview = true,
    bool wrapEnabled = false,
    int tabSize = 2,
    required EditorEngine engine,
  }) async {
    selectTreePath(path);

    final existing = _editorsByPath[path];
    if (existing != null) {
      if (!preview) {
        existing.isPreview = false;
        if (_previewPath == path) {
          _previewPath = null;
        }
      }
      _activePath = path;
      notifyListeners();
      return;
    }

    if (preview) {
      final oldPreviewPath = _previewPath;
      if (oldPreviewPath != null && oldPreviewPath != path) {
        _removeEditor(oldPreviewPath);
      }
      _previewPath = path;
    }

    late final CodeWorkbenchEditorState editor;
    final controller = await AppCodeEditorController.create(
      engine: engine,
      filePath: path,
      tabSize: tabSize,
      wrapEnabled: wrapEnabled,
    );
    editor = CodeWorkbenchEditorState(
      path: path,
      controller: controller,
      controllerListener: () => _handleControllerChanged(editor),
      isPreview: preview,
      loading: true,
      wrapEnabled: wrapEnabled,
    );
    controller.addListener(editor.controllerListener);
    _editorsByPath[path] = editor;
    _openPaths.add(path);
    _activePath = path;
    notifyListeners();

    try {
      final raw = await _service.getProjectStorageFile(projectId, path);
      final content = CodeTabFileContent.fromJson(raw);
      editor.content = content;
      editor.error = null;
      editor.loading = false;
      editor.originalContent = content.content;
      await editor.controller.setLanguageForPath(path);
      await editor.controller.setText(content.content, markSaved: true);
      editor.lastKnownDirty = editor.hasUnsavedChanges;
    } catch (e) {
      editor.error = e.toString();
      editor.loading = false;
      editor.content = null;
    }

    notifyListeners();
  }

  void activateEditor(String path) {
    if (_activePath == path) return;
    _activePath = path;
    _selectedTreePath = path;
    notifyListeners();
  }

  void pinEditor(String path) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    editor.isPreview = false;
    if (_previewPath == path) {
      _previewPath = null;
    }
    _activePath = path;
    notifyListeners();
  }

  void enterEditMode(String path) {
    final editor = _editorsByPath[path];
    if (editor == null || editor.content == null || editor.isBinary) return;
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
    await editor.controller.setWrapEnabled(editor.wrapEnabled);
    notifyListeners();
  }

  Future<void> applyEditorPreferences({
    required bool defaultWrap,
    required int tabSize,
    required EditorEngine engine,
  }) async {
    final shouldRebuildControllers = _editorsByPath.values.any(
      (editor) => editor.controller.engine != engine,
    );

    if (shouldRebuildControllers) {
      await _rebuildControllersForEngine(engine, tabSize: tabSize);
    }

    for (final editor in _editorsByPath.values) {
      editor.wrapEnabled = defaultWrap;
      await editor.controller.setTabSpaces(tabSize);
      await editor.controller.setWrapEnabled(defaultWrap);
    }
    notifyListeners();
  }

  Future<void> cancelEdit(String path) async {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    await editor.controller.setText(editor.originalContent, markSaved: true);
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
    final current = await editor.controller.readText();
    if (current == text) return;
    await editor.controller.setText(text);
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
    unawaited(editor.controller.setLanguageForPath(path));
    unawaited(
      editor.controller.setText(
        content.isBinary ? '' : content.content,
        markSaved: true,
      ),
    );
    editor.isEditing = keepEditing && !content.isBinary;
    _syncedPaths.add(path);
    _syncStates[path] = CodeWorkbenchSyncState.synced;
    _queuedAt.remove(path);
    editor.lastKnownDirty = editor.hasUnsavedChanges;
    notifyListeners();
  }

  void markPathLocalSaved(String path) {
    _syncedPaths.remove(path);
    _syncStates[path] = CodeWorkbenchSyncState.localSaved;
    _queuedAt[path] = DateTime.now();
    notifyListeners();
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
      final latestText = await editor.controller.readText(refresh: true);
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
      await editor.controller.markSaved();
      editor.isEditing = false;
      _syncedPaths.add(path);
      _syncStates[path] = CodeWorkbenchSyncState.synced;
      _queuedAt.remove(path);
      editor.lastKnownDirty = editor.hasUnsavedChanges;
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
    await editor.controller.setText(editor.originalContent, markSaved: true);
    editor.isEditing = false;
    _syncedPaths.add(path);
    _syncStates[path] = CodeWorkbenchSyncState.synced;
    _queuedAt.remove(path);
    editor.lastKnownDirty = editor.hasUnsavedChanges;
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
      _selectedTreePath = _activePath;
    }
    notifyListeners();
  }

  void _removeEditor(String path) {
    final editor = _editorsByPath.remove(path);
    _openPaths.remove(path);
    if (editor != null) {
      editor.controller.removeListener(editor.controllerListener);
    }
    editor?.controller.dispose();
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
      editor.controller.dispose();
    }
    _editorsByPath.clear();
    _openPaths.clear();
    super.dispose();
  }

  Future<void> _rebuildControllersForEngine(
    EditorEngine engine, {
    required int tabSize,
  }) async {
    final snapshots =
        <
          ({
            String path,
            String text,
            String originalContent,
            CodeTabFileContent? content,
            String? error,
            bool loading,
            bool saving,
            bool isEditing,
            bool isPreview,
            bool wrapEnabled,
            bool lastKnownDirty,
          })
        >[];

    for (final path in _openPaths) {
      final editor = _editorsByPath[path];
      if (editor == null) continue;
      snapshots.add((
        path: path,
        text: await editor.controller.readText(refresh: true),
        originalContent: editor.originalContent,
        content: editor.content,
        error: editor.error,
        loading: editor.loading,
        saving: editor.saving,
        isEditing: editor.isEditing,
        isPreview: editor.isPreview,
        wrapEnabled: editor.wrapEnabled,
        lastKnownDirty: editor.lastKnownDirty,
      ));
    }

    for (final editor in _editorsByPath.values) {
      editor.controller.removeListener(editor.controllerListener);
      editor.controller.dispose();
    }
    _editorsByPath.clear();

    for (final snapshot in snapshots) {
      late final CodeWorkbenchEditorState editorState;
      final controller = await AppCodeEditorController.create(
        engine: engine,
        filePath: snapshot.path,
        tabSize: tabSize,
        wrapEnabled: snapshot.wrapEnabled,
      );
      editorState = CodeWorkbenchEditorState(
        path: snapshot.path,
        controller: controller,
        controllerListener: () => _handleControllerChanged(editorState),
        isPreview: snapshot.isPreview,
        content: snapshot.content,
        error: snapshot.error,
        loading: snapshot.loading,
        saving: snapshot.saving,
        isEditing: snapshot.isEditing,
        wrapEnabled: snapshot.wrapEnabled,
        originalContent: snapshot.originalContent,
        lastKnownDirty: snapshot.lastKnownDirty,
      );
      controller.addListener(editorState.controllerListener);
      await controller.setLanguageForPath(snapshot.path);
      await controller.setText(
        snapshot.text,
        markSaved: snapshot.text == snapshot.originalContent,
      );
      _editorsByPath[snapshot.path] = editorState;
    }
  }
}
