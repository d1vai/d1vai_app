import 'package:flutter/material.dart';

import '../../file_preview.dart';
import 'code_tab_editing_pane.dart';
import 'code_tab_editor_language.dart';
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
  final VoidCallback? onToggleWrap;
  final ValueChanged<String>? onChange;
  final VoidCallback? onSave;
  final VoidCallback? onCopy;

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
    required this.onToggleWrap,
    required this.onChange,
    required this.onSave,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final editor = activeEditor;
    final p = editor?.path;
    final content = editor?.content;
    final loading = editor?.loading == true;
    final error = editor?.error;
    final isEditing = editor?.isEditing == true;
    final editController = editor?.controller;
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
                : isEditing
                ? CodeTabEditingPane(
                    controller: editController,
                    originalText: editor?.originalContent ?? '',
                    languageLabel: languageLabelForPath(p),
                    wrapEnabled: editor?.wrapEnabled ?? false,
                    onChanged: onChange,
                    onCancel: onCancelEdit,
                    onToggleWrap: onToggleWrap,
                    compact: compact,
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: FilePreview(
                          path: p ?? content.path,
                          content: content.content,
                          isBinary: content.isBinary,
                          sizeBytes: content.size,
                        ),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEnterEdit,
                            onDoubleTap: onEnterEdit,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
