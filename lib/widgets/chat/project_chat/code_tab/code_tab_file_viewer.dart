import 'package:flutter/material.dart';

import 'code_tab_code_block.dart';
import 'code_tab_editor.dart';
import 'code_tab_models.dart';
import 'code_tab_views.dart';

class CodeTabFileViewer extends StatelessWidget {
  final ThemeData theme;
  final String? filePath;
  final bool loading;
  final String? error;
  final CodeTabFileContent? content;
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

  const CodeTabFileViewer({
    super.key,
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
                ? CodeTabErrorView(
                    title: 'Failed to open file',
                    message: error!,
                    onRetry: null,
                  )
                : content == null
                ? const CodeTabEmptyView(text: 'Pick a file from the tree')
                : GestureDetector(
                    onDoubleTap: onEnterEdit,
                    child: isEditing
                        ? CodeTabEditor(
                            controller: editController,
                            onChanged: onChange,
                            onCancel: onCancelEdit,
                            dirty: hasUnsavedChanges,
                          )
                        : CodeTabCodeBlock(
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
