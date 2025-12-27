import 'package:flutter/material.dart';

class CodeTabEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final bool dirty;

  const CodeTabEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCancel,
    required this.dirty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tint = dirty ? colorScheme.tertiary : colorScheme.primary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(
                dirty ? Icons.circle : Icons.check_circle,
                size: 14,
                color: tint.withValues(alpha: dirty ? 0.9 : 0.95),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirty ? 'Editing (unsaved changes)' : 'Editing',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Color.alphaBlend(
                colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.04),
                colorScheme.surface,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

