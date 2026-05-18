import 'package:flutter/material.dart';

import 'code_workbench_controller.dart';

class CodeTabEditorTabs extends StatelessWidget {
  final List<CodeWorkbenchEditorState> editors;
  final String? activePath;
  final bool compact;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onPin;
  final ValueChanged<String> onClose;

  const CodeTabEditorTabs({
    super.key,
    required this.editors,
    required this.activePath,
    required this.compact,
    required this.onSelect,
    required this.onPin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = compact ? 34.0 : 40.0;
    if (editors.isEmpty) {
      return SizedBox(height: height);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                  minWidth: compact ? 132 : 148,
                  maxWidth: compact ? 224 : 260,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surface,
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
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 12.5,
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
                            fontSize: compact ? 10 : 10.5,
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
                        padding: EdgeInsets.all(compact ? 2 : 4),
                        child: Icon(
                          Icons.close,
                          size: compact ? 14 : 16,
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
