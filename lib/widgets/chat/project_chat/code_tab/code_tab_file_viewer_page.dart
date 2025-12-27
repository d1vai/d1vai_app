import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/d1vai_service.dart';
import '../../../snackbar_helper.dart';
import 'code_tab_editor.dart';
import 'code_tab_models.dart';
import 'code_tab_types.dart';
import 'code_tab_views.dart';
import 'code_tab_code_block.dart';

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
        _content = CodeTabFileContent.fromJson(raw);
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
      final commitSha =
          commit is Map<String, dynamic> ? commit['sha']?.toString() : null;
      final shortSha = (commitSha != null && commitSha.length >= 7)
          ? commitSha.substring(0, 7)
          : null;

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Saved',
        message:
            shortSha == null ? 'Saved successfully' : 'Saved (commit: $shortSha)',
      );

      setState(() {
        _content = CodeTabFileContent(
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
                ? CodeTabErrorView(
                    title: 'Failed to open file',
                    message: _error!,
                    onRetry: _load,
                  )
                : content == null
                ? const CodeTabEmptyView(text: 'No content')
                : GestureDetector(
                    onDoubleTap: _enterEdit,
                    child: _isEditing
                        ? CodeTabEditor(
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
                        : CodeTabCodeBlock(
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

