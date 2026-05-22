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
    final activePath = editor?.path;
    final activeIndex = activePath == null
        ? -1
        : editors.indexWhere((item) => item.path == activePath);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          CodeTabEditorTabs(
            editors: editors,
            activePath: activePath,
            compact: compact,
            isSynced: isSynced ?? (_) => false,
            syncStateFor: syncStateFor ?? (_) => CodeWorkbenchSyncState.idle,
            queuedDurationFor: queuedDurationFor,
            onSelect: onSelectTab ?? (_) {},
            onPin: onPinTab ?? (_) {},
            onClose: onCloseTab ?? (_) {},
          ),
          Expanded(
            child: activeIndex < 0
                ? const CodeTabEmptyView(text: 'Pick a file from the tree')
                : IndexedStack(
                    index: activeIndex,
                    children: editors
                        .map(
                          (item) => KeyedSubtree(
                            key: ValueKey(item.path),
                            child: _EditorSurface(
                              editor: item,
                              compact: compact,
                              onEnterEdit: activePath == item.path
                                  ? onEnterEdit
                                  : null,
                              onCancelEdit: activePath == item.path
                                  ? onCancelEdit
                                  : null,
                              onToggleWrap: activePath == item.path
                                  ? onToggleWrap
                                  : null,
                              onChange: activePath == item.path
                                  ? onChange
                                  : null,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditorSurface extends StatelessWidget {
  final CodeWorkbenchEditorState editor;
  final bool compact;
  final VoidCallback? onEnterEdit;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onToggleWrap;
  final ValueChanged<String>? onChange;

  const _EditorSurface({
    required this.editor,
    required this.compact,
    required this.onEnterEdit,
    required this.onCancelEdit,
    required this.onToggleWrap,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final content = editor.content;
    final error = editor.error;

    if (editor.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return CodeTabErrorView(
        title: 'Failed to open file',
        message: error,
        onRetry: null,
      );
    }

    if (content == null) {
      return const CodeTabEmptyView(text: 'Pick a file from the tree');
    }

    if (editor.isEditing) {
      return CodeTabEditingPane(
        controller: editor.controller,
        originalText: editor.originalContent,
        languageLabel: languageLabelForPath(editor.path),
        wrapEnabled: editor.wrapEnabled,
        onChanged: onChange,
        onCancel: onCancelEdit,
        onToggleWrap: onToggleWrap,
        compact: compact,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FilePreview(
            path: editor.path,
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
    );
  }
}
