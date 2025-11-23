import 'package:flutter/material.dart';
import 'tool_container.dart';

/// Write tool message renderer
class WriteTool extends StatelessWidget {
  final dynamic input;

  const WriteTool({
    super.key,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String filePath = '';
    String content = '';
    bool? append;
    bool? createFolders;

    if (input is Map) {
      filePath = input['file_path']?.toString() ?? '';
      content = input['content']?.toString() ?? '';
      append = input['append'] as bool?;
      createFolders = input['create_folders'] as bool?;
    }

    return ToolContainer(
      toolType: 'Write',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  filePath,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (append == true || createFolders == true) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (append == true)
                  _OptionChip(
                    label: 'Append',
                    icon: Icons.add_circle_outline,
                  ),
                if (createFolders == true)
                  _OptionChip(
                    label: 'Create folders',
                    icon: Icons.create_new_folder_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _OptionChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSecondaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
