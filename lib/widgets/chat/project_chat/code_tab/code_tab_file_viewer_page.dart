import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../providers/editor_preferences_provider.dart';
import '../../../../services/d1vai_service.dart';
import '../../../snackbar_helper.dart';
import '../../file_preview.dart';
import '../../file_preview_utils.dart';
import 'app_code_editor_controller.dart';
import 'code_tab_editing_pane.dart';
import 'code_tab_editor_language.dart';
import 'code_tab_models.dart';
import 'code_tab_run_migration_bottom_sheet.dart';
import 'code_tab_types.dart';
import 'code_tab_views.dart';

class CodeTabFileViewerPage extends StatefulWidget {
  final String projectId;
  final String filePath;
  final ValueChanged<String> onAsk;

  const CodeTabFileViewerPage({
    super.key,
    required this.projectId,
    required this.filePath,
    required this.onAsk,
  });

  @override
  State<CodeTabFileViewerPage> createState() => _CodeTabFileViewerPageState();
}

class _CodeTabFileViewerPageState extends State<CodeTabFileViewerPage> {
  final D1vaiService _service = D1vaiService();
  bool _loading = false;
  String? _error;
  CodeTabFileContent? _content;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _wrapEnabled = false;
  String _editOriginal = '';
  AppCodeEditorController? _editController;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<EditorPreferencesProvider>();
    _wrapEnabled = prefs.defaultWrap;
    unawaited(_initializeEditorAndLoad(prefs));
  }

  @override
  void dispose() {
    _editController?.removeListener(_handleEditorChanged);
    _editController?.dispose();
    super.dispose();
  }

  Future<void> _initializeEditorAndLoad(EditorPreferencesProvider prefs) async {
    final controller = await AppCodeEditorController.create(
      filePath: widget.filePath,
      tabSize: prefs.tabSize,
      wrapEnabled: prefs.defaultWrap,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    controller.addListener(_handleEditorChanged);
    setState(() {
      _editController = controller;
    });
    await _load();
  }

  void _handleEditorChanged() {
    final dirty = _editController?.hasUnsavedChanges ?? false;
    if (dirty == _hasUnsavedChanges) return;
    if (!mounted) return;
    setState(() {
      _hasUnsavedChanges = dirty;
    });
  }

  Future<void> _load() async {
    final editController = _editController;
    if (editController == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _content = null;
      _isEditing = false;
      _hasUnsavedChanges = false;
      _isSaving = false;
      _editOriginal = '';
    });
    await editController.setText('', markSaved: true);
    try {
      final raw = await _service.getProjectStorageFile(
        widget.projectId,
        widget.filePath,
      );
      final content = CodeTabFileContent.fromJson(raw);
      await editController.setLanguageForPath(widget.filePath);
      await editController.setText(content.content, markSaved: true);
      final shouldOpenDirectlyInEditor =
          !content.isBinary &&
          supportsMonacoTextPreview() &&
          shouldOpenPathDirectlyInMonacoEditor(widget.filePath);
      if (!mounted) return;
      setState(() {
        _content = content;
        _editOriginal = content.content;
        _hasUnsavedChanges = false;
        _isEditing = shouldOpenDirectlyInEditor;
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

  Future<void> _enterEdit() async {
    final content = _content;
    final editController = _editController;
    if (content == null ||
        editController == null ||
        !isEditableFilePreview(widget.filePath, content.isBinary) ||
        _isEditing) {
      return;
    }
    await editController.setLanguageForPath(widget.filePath);
    await editController.setText(content.content, markSaved: true);
    if (!mounted) return;
    setState(() {
      _isEditing = true;
      _editOriginal = content.content;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _enterEditAtPosition({
    required int line,
    required int column,
  }) async {
    final content = _content;
    final editController = _editController;
    if (content == null ||
        editController == null ||
        !isEditableFilePreview(widget.filePath, content.isBinary)) {
      return;
    }
    await _enterEdit();
    if (!mounted) return;
    await editController.focusPosition(line: line, column: column);
  }

  Future<void> _save() async {
    final content = _content;
    final editController = _editController;
    if (content == null ||
        editController == null ||
        !isEditableFilePreview(widget.filePath, content.isBinary) ||
        !_isEditing ||
        !_hasUnsavedChanges ||
        _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final fileName = widget.filePath.split('/').isEmpty
          ? 'file'
          : widget.filePath.split('/').last;
      final latestText = await editController.readText(refresh: true);
      final result = await _service.syncFileToGitHub(
        widget.projectId,
        filePath: widget.filePath,
        content: latestText,
        commitMessage: 'feat: update $fileName',
      );

      final commit = result['commit'];
      final commitSha = commit is Map<String, dynamic>
          ? commit['sha']?.toString()
          : null;
      final shortSha = (commitSha != null && commitSha.length >= 7)
          ? commitSha.substring(0, 7)
          : null;

      await editController.markSaved();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Saved',
        message: shortSha == null
            ? 'Saved successfully'
            : 'Saved (commit: $shortSha)',
      );

      setState(() {
        _content = CodeTabFileContent(
          path: content.path,
          content: latestText,
          size: latestText.length,
          isBinary: false,
        );
        _editOriginal = latestText;
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
      await _editController?.setText(_editOriginal, markSaved: true);
      if (!mounted) return false;
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
      });
      return true;
    }
    await _save();
    return !_isEditing;
  }

  @override
  Widget build(BuildContext context) {
    final editorPrefs = context.watch<EditorPreferencesProvider>();
    final editController = _editController;
    if (editController != null) {
      if (editController.tabSize != editorPrefs.tabSize) {
        unawaited(editController.setTabSpaces(editorPrefs.tabSize));
      }
    }

    final theme = Theme.of(context);
    final content = _content;
    final isSqlFile = widget.filePath.toLowerCase().trim().endsWith('.sql');
    final canEditCurrent =
        content != null &&
        isEditableFilePreview(widget.filePath, content.isBinary);
    final canCopyCurrent =
        content != null &&
        isCopyableFilePreview(widget.filePath, content.isBinary);
    final useMonacoPreview =
        canEditCurrent &&
        supportsMonacoTextPreview() &&
        shouldOpenPathDirectlyInMonacoEditor(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isSqlFile && content != null && !content.isBinary)
            _PageToolbarIconButton(
              onPressed: () {
                showRunSqlMigrationBottomSheet(
                  context,
                  projectId: widget.projectId,
                  sql: content.content,
                  sourcePath: widget.filePath,
                );
              },
              icon: Icons.play_arrow_outlined,
              tooltip: 'Run SQL migration',
            ),
          _PageToolbarIconButton(
            onPressed: () {
              widget.onAsk(
                'Please review the file "${widget.filePath}". Summarize what it does and propose improvements. '
                'If there are bugs or missing pieces, suggest concrete edits.',
              );
              Navigator.of(context).pop();
            },
            icon: Icons.auto_awesome_outlined,
            tooltip: 'Ask AI',
          ),
          if (canEditCurrent)
            _PageToolbarIconButton(
              onPressed: _isEditing
                  ? (_isSaving || !_hasUnsavedChanges ? null : _save)
                  : () => unawaited(_enterEdit()),
              icon: _isEditing ? Icons.save_outlined : Icons.edit_outlined,
              tooltip: _isEditing ? 'Save' : 'Edit',
              busy: _isSaving,
            ),
          if (_isEditing)
            _PageToolbarIconButton(
              onPressed: editController?.showSearch,
              icon: Icons.search_outlined,
              tooltip: 'Find',
            ),
          if (_isEditing)
            _PageToolbarIconButton(
              onPressed: () {
                setState(() {
                  _wrapEnabled = !_wrapEnabled;
                });
                unawaited(
                  editController?.setWrapEnabled(_wrapEnabled) ??
                      Future<void>.value(),
                );
              },
              icon: _wrapEnabled ? Icons.wrap_text : Icons.wrap_text_outlined,
              tooltip: _wrapEnabled ? 'Disable wrap' : 'Enable wrap',
            ),
          if (_isEditing && (editController?.supportsFoldAll ?? false))
            _PageFoldActionsMenu(
              onFoldAll: editController!.foldAll,
              onUnfoldAll: editController.unfoldAll,
              onFoldImports: editController.supportsFoldImports
                  ? editController.foldImports
                  : null,
              onFoldHeader: editController.supportsFoldHeader
                  ? editController.foldHeader
                  : null,
            ),
          if (canCopyCurrent)
            _PageToolbarIconButton(
              onPressed: () async {
                final text = _isEditing
                    ? (await _editController?.readText(refresh: true) ?? '')
                    : content.content;
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                SnackBarHelper.showSuccess(
                  context,
                  title: 'Copied',
                  message: 'File content copied',
                  duration: const Duration(seconds: 2),
                );
              },
              icon: Icons.copy_outlined,
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
            child: _loading || _editController == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? CodeTabErrorView(
                    title: 'Failed to open file',
                    message: _error!,
                    onRetry: _load,
                  )
                : content == null
                ? const CodeTabEmptyView(text: 'No content')
                : _isEditing
                ? CodeTabEditingPane(
                    controller: _editController!,
                    originalText: _editOriginal,
                    languageLabel: languageLabelForPath(widget.filePath),
                    wrapEnabled: _wrapEnabled,
                    onChanged: null,
                    onCancel: () async {
                      final ok = await _confirmLeave();
                      if (!ok) return;
                      await _editController?.setText(
                        _editOriginal,
                        markSaved: true,
                      );
                      if (!mounted) return;
                      setState(() {
                        _isEditing = false;
                        _hasUnsavedChanges = false;
                      });
                    },
                    onToggleWrap: () {
                      setState(() {
                        _wrapEnabled = !_wrapEnabled;
                      });
                      unawaited(
                        _editController?.setWrapEnabled(_wrapEnabled) ??
                            Future<void>.value(),
                      );
                    },
                    compact: false,
                  )
                : useMonacoPreview
                ? FilePreview(
                    path: widget.filePath,
                    content: content.content,
                    isBinary: false,
                    sizeBytes: content.size,
                    preferMonacoWhenEditable: true,
                    onActivateTextPosition: (line, column) {
                      unawaited(
                        _enterEditAtPosition(line: line, column: column),
                      );
                    },
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => unawaited(_enterEdit()),
                    child: FilePreview(
                      path: widget.filePath,
                      content: content.content,
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

class _PageToolbarIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final bool busy;

  const _PageToolbarIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 17,
      splashRadius: 16,
      padding: const EdgeInsets.all(5),
      color: theme.colorScheme.onSurfaceVariant.withValues(
        alpha: onPressed == null ? 0.38 : 0.78,
      ),
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      tooltip: tooltip,
    );
  }
}

class _PageFoldActionsMenu extends StatelessWidget {
  final VoidCallback onFoldAll;
  final VoidCallback onUnfoldAll;
  final VoidCallback? onFoldImports;
  final VoidCallback? onFoldHeader;

  const _PageFoldActionsMenu({
    required this.onFoldAll,
    required this.onUnfoldAll,
    required this.onFoldImports,
    required this.onFoldHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Fold options',
      padding: EdgeInsets.zero,
      iconSize: 17,
      splashRadius: 16,
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
