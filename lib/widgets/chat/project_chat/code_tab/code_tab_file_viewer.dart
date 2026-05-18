import 'package:flutter/material.dart';

import '../../file_preview.dart';
import '../../file_preview_utils.dart';
import 'code_tab_editor.dart';
import 'code_tab_editor_tabs.dart';
import 'code_tab_views.dart';
import 'code_workbench_controller.dart';

class CodeTabFileViewer extends StatelessWidget {
  final ThemeData theme;
  final List<CodeWorkbenchEditorState> editors;
  final CodeWorkbenchEditorState? activeEditor;
  final bool compact;
  final ValueChanged<String>? onSelectTab;
  final ValueChanged<String>? onPinTab;
  final ValueChanged<String>? onCloseTab;
  final VoidCallback? onEnterEdit;
  final VoidCallback? onCancelEdit;
  final ValueChanged<String>? onChange;
  final VoidCallback? onSave;
  final VoidCallback? onCopy;
  final VoidCallback? onAsk;

  const CodeTabFileViewer({
    super.key,
    required this.theme,
    required this.editors,
    required this.activeEditor,
    required this.compact,
    required this.onSelectTab,
    required this.onPinTab,
    required this.onCloseTab,
    required this.onEnterEdit,
    required this.onCancelEdit,
    required this.onChange,
    required this.onSave,
    required this.onCopy,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final editor = activeEditor;
    final p = editor?.path;
    final content = editor?.content;
    final loading = editor?.loading == true;
    final error = editor?.error;
    final isEditing = editor?.isEditing == true;
    final hasUnsavedChanges = editor?.hasUnsavedChanges == true;
    final saving = editor?.saving == true;
    final editController = editor?.controller;
    final canEditCurrent =
        p != null &&
        content != null &&
        isEditableFilePreview(p, content.isBinary);
    final canCopyCurrent =
        p != null &&
        content != null &&
        isCopyableFilePreview(p, content.isBinary);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(compact ? 8 : 14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          CodeTabEditorTabs(
            editors: editors,
            activePath: editor?.path,
            compact: compact,
            onSelect: onSelectTab ?? (_) {},
            onPin: onPinTab ?? (_) {},
            onClose: onCloseTab ?? (_) {},
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 10,
            ),
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
                if (p != null && p.isNotEmpty && canEditCurrent)
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
                if (canCopyCurrent)
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
                ? CodeTabErrorView(
                    title: 'Failed to open file',
                    message: error,
                    onRetry: null,
                  )
                : content == null || editController == null
                ? const CodeTabEmptyView(text: 'Pick a file from the tree')
                : GestureDetector(
                    onDoubleTap: onEnterEdit,
                    child: isEditing
                        ? CodeTabEditor(
                            controller: editController,
                            onChanged: onChange,
                            onCancel: onCancelEdit,
                            dirty: hasUnsavedChanges,
                            compact: compact,
                          )
                        : FilePreview(
                            path: p ?? content.path,
                            content: content.content,
                            isBinary: content.isBinary,
                            sizeBytes: content.size,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
