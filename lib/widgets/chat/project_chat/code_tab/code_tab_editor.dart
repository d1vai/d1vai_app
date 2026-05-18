import 'package:flutter/material.dart';

class CodeTabEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final bool dirty;
  final bool compact;

  const CodeTabEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCancel,
    required this.dirty,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tint = dirty ? colorScheme.tertiary : colorScheme.primary;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
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
                  dirty ? 'Unsaved changes' : 'Editing',
                  style: TextStyle(
                    fontSize: compact ? 11 : 11.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: onCancel,
                child: const Text('Revert'),
              ),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 9 : 11,
              ),
              filled: true,
              fillColor: colorScheme.surface,
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
