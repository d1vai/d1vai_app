import 'package:flutter/material.dart';

import 'code_workbench_controller.dart';

class CodeTabEditorTabs extends StatelessWidget {
  final List<CodeWorkbenchEditorState> editors;
  final String? activePath;
  final bool compact;
  final bool Function(String path)? isSynced;
  final CodeWorkbenchSyncState Function(String path)? syncStateFor;
  final Duration? Function(String path)? queuedDurationFor;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onPin;
  final ValueChanged<String> onClose;

  const CodeTabEditorTabs({
    super.key,
    required this.editors,
    required this.activePath,
    required this.compact,
    required this.isSynced,
    required this.syncStateFor,
    required this.queuedDurationFor,
    required this.onSelect,
    required this.onPin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = compact ? 31.0 : 38.0;
    if (editors.isEmpty) {
      return SizedBox(height: height);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: editors.length,
        itemBuilder: (context, index) {
          final editor = editors[index];
          final active = editor.path == activePath;
          final name = editor.path.split('/').last;
          return GestureDetector(
            onDoubleTap: () => onPin(editor.path),
            child: InkWell(
              onTap: () => onSelect(editor.path),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                constraints: BoxConstraints(
                  minWidth: compact ? 126 : 142,
                  maxWidth: compact ? 216 : 252,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 11,
                  vertical: compact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceContainerLowest,
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant),
                    top: active
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    _DirtyDot(
                      visible: editor.hasUnsavedChanges,
                      compact: compact,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    _SyncDot(
                      state: syncStateFor?.call(editor.path) ??
                          (isSynced?.call(editor.path) == true
                              ? CodeWorkbenchSyncState.synced
                              : CodeWorkbenchSyncState.idle),
                      queuedDuration: queuedDurationFor?.call(editor.path),
                      compact: compact,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11.75 : 12.25,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontStyle: editor.isPreview
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (editor.isPreview)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: compact ? 9.5 : 10,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onClose(editor.path),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 2 : 3),
                        child: Icon(
                          Icons.close,
                          size: compact ? 13 : 15,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DirtyDot extends StatelessWidget {
  final bool visible;
  final bool compact;
  final Color color;

  const _DirtyDot({
    required this.visible,
    required this.compact,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: compact ? 7 : 8,
      height: compact ? 7 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visible ? color : Colors.transparent,
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  final CodeWorkbenchSyncState state;
  final Duration? queuedDuration;
  final bool compact;
  final Color color;

  const _SyncDot({
    required this.state,
    required this.queuedDuration,
    required this.compact,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final visible = state == CodeWorkbenchSyncState.synced;
    final stateColor = switch (state) {
      CodeWorkbenchSyncState.idle => Colors.transparent,
      CodeWorkbenchSyncState.localSaved => color.withValues(alpha: 0.5),
      CodeWorkbenchSyncState.queued => Colors.orange,
      CodeWorkbenchSyncState.syncingCloud => Colors.orangeAccent,
      CodeWorkbenchSyncState.syncingGitHub => color,
      CodeWorkbenchSyncState.synced => color,
      CodeWorkbenchSyncState.failed => Colors.redAccent,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: compact ? 6 : 7,
      height: compact ? 6 : 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visible || state != CodeWorkbenchSyncState.idle
            ? stateColor
            : Colors.transparent,
      ),
    );
  }
}
