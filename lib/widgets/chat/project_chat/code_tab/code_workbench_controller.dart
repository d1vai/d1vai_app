import 'package:flutter/material.dart';

import '../../../../services/d1vai_service.dart';
import 'code_tab_models.dart';

class CodeWorkbenchEditorState {
  final String path;
  final TextEditingController controller;
  CodeTabFileContent? content;
  String? error;
  bool loading;
  bool saving;
  bool isEditing;
  bool isPreview;
  String originalContent;

  CodeWorkbenchEditorState({
    required this.path,
    required this.controller,
    required this.isPreview,
    this.content,
    this.error,
    this.loading = false,
    this.saving = false,
    this.isEditing = false,
    this.originalContent = '',
  });

  bool get hasUnsavedChanges => controller.text != originalContent;
  bool get isBinary => content?.isBinary == true;
}

enum CodeWorkbenchSourceMode { cloudOnly, localAttached, hybrid }

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

  Future<void> openFile(
    String projectId,
    String path, {
    bool preview = true,
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

    final editor = CodeWorkbenchEditorState(
      path: path,
      controller: TextEditingController(),
      isPreview: preview,
      loading: true,
    );
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
      editor.controller.text = content.content;
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

  void cancelEdit(String path) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    editor.controller.text = editor.originalContent;
    editor.isEditing = false;
    notifyListeners();
  }

  void updateText(String path, String text) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    if (editor.controller.text == text) return;
    editor.controller.value = editor.controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    notifyListeners();
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
    editor.controller.text = content.isBinary ? '' : content.content;
    editor.isEditing = keepEditing && !content.isBinary;
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
    notifyListeners();

    try {
      final fileName = path.split('/').isEmpty ? 'file' : path.split('/').last;
      final result = await _service.syncFileToGitHub(
        projectId,
        filePath: path,
        content: editor.controller.text,
        commitMessage: 'feat: update $fileName',
      );
      final commit = result['commit'];
      final commitSha = commit is Map<String, dynamic>
          ? commit['sha']?.toString()
          : null;
      editor.content = CodeTabFileContent(
        path: content.path,
        content: editor.controller.text,
        size: editor.controller.text.length,
        isBinary: false,
      );
      editor.originalContent = editor.controller.text;
      editor.isEditing = false;
      return commitSha;
    } finally {
      editor.saving = false;
      notifyListeners();
    }
  }

  void discardChanges(String path) {
    final editor = _editorsByPath[path];
    if (editor == null) return;
    editor.controller.text = editor.originalContent;
    editor.isEditing = false;
    notifyListeners();
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
    editor?.controller.dispose();
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
}
