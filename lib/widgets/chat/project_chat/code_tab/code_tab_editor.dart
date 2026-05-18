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
    final text = controller.text;
    final lineCount = '\n'.allMatches(text).length + 1;
    final charCount = text.characters.length;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
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
              fontSize: 12.25,
              height: 1.3,
            ),
          ),
        ),
        Container(
          height: compact ? 24 : 26,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
          ),
          child: Row(
            children: [
              Text(
                dirty ? 'LOCAL CHANGES' : 'EDITOR',
                style: TextStyle(
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: tint,
                ),
              ),
              const Spacer(),
              Text(
                '$lineCount lines',
                style: TextStyle(
                  fontSize: compact ? 10 : 10.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$charCount chars',
                style: TextStyle(
                  fontSize: compact ? 10 : 10.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 2,
          color: dirty ? tint.withValues(alpha: 0.85) : colorScheme.primary.withValues(alpha: 0.28),
        ),
      ],
    );
  }
}
