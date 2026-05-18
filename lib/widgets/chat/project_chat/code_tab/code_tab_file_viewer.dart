import 'package:flutter/material.dart';

import '../../file_preview.dart';
import '../../file_preview_utils.dart';
import '../../file_type_visual.dart';
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
  final bool Function(String path)? isSynced;
  final CodeWorkbenchSyncState Function(String path)? syncStateFor;
  final Duration? Function(String path)? queuedDurationFor;
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
    required this.isSynced,
    required this.syncStateFor,
    required this.queuedDurationFor,
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
    final syncState = p == null
        ? CodeWorkbenchSyncState.idle
        : (syncStateFor?.call(p) ?? CodeWorkbenchSyncState.idle);
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
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          CodeTabEditorTabs(
            editors: editors,
            activePath: editor?.path,
            compact: compact,
            isSynced: isSynced ?? (_) => false,
            syncStateFor: syncStateFor ?? (_) => CodeWorkbenchSyncState.idle,
            queuedDurationFor: queuedDurationFor,
            onSelect: onSelectTab ?? (_) {},
            onPin: onPinTab ?? (_) {},
            onClose: onCloseTab ?? (_) {},
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
                        ? Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 10 : 12,
                                  vertical: compact ? 7 : 9,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (p != null && p.isNotEmpty) ...[
                                      buildFileTypeIcon(
                                        context,
                                        p,
                                        size: compact ? 15 : 17,
                                        fallbackColor: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        p == null || p.isEmpty
                                            ? 'Editing'
                                            : p.split('/').last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: compact ? 12.25 : 13,
                                        ),
                                      ),
                                    ),
                                    _SyncPill(
                                      state: syncState,
                                      compact: compact,
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: onAsk,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.auto_awesome_outlined),
                                      tooltip: 'Ask AI',
                                    ),
                                    if (p != null &&
                                        p.isNotEmpty &&
                                        canEditCurrent)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: saving || !hasUnsavedChanges
                                            ? null
                                            : onSave,
                                        icon: saving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.save),
                                        tooltip: 'Save',
                                      ),
                                    if (canCopyCurrent)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: onCopy,
                                        icon: const Icon(Icons.copy_outlined),
                                        tooltip: 'Copy',
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: CodeTabEditor(
                                  controller: editController,
                                  onChanged: onChange,
                                  onCancel: onCancelEdit,
                                  dirty: hasUnsavedChanges,
                                  compact: compact,
                                ),
                              ),
                            ],
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

class _SyncPill extends StatelessWidget {
  final CodeWorkbenchSyncState state;
  final bool compact;

  const _SyncPill({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (state) {
      CodeWorkbenchSyncState.idle => ('Ready', theme.colorScheme.onSurfaceVariant),
      CodeWorkbenchSyncState.localSaved => ('Local', theme.colorScheme.primary),
      CodeWorkbenchSyncState.queued => ('Queued', Colors.orange),
      CodeWorkbenchSyncState.syncingCloud => ('Cloud', theme.colorScheme.secondary),
      CodeWorkbenchSyncState.syncingGitHub => ('Syncing', theme.colorScheme.tertiary),
      CodeWorkbenchSyncState.synced => ('Synced', Colors.green),
      CodeWorkbenchSyncState.failed => ('Failed', Colors.redAccent),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
