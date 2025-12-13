import 'package:flutter/material.dart';
import '../../../models/message.dart';
import 'bash_tool.dart';
import 'write_tool.dart';
import 'read_tool.dart';
import 'tool_container.dart';

/// Enhanced tool message renderer with specialized components for different tool types
class EnhancedToolMessage extends StatelessWidget {
  final ToolMessageContent content;

  const EnhancedToolMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final toolName = content.name.toLowerCase();

    switch (toolName) {
      case 'bash':
        return BashTool(input: content.input);

      case 'write':
        return WriteTool(input: content.input);

      case 'read':
        return ReadTool(input: content.input);

      case 'edit':
        return _EditTool(input: content.input);

      case 'multi_edit':
        return _EditTool(input: content.input, isMulti: true);

      case 'glob':
        return _SimpleTool(
          toolName: 'Glob',
          input: content.input,
          icon: Icons.search,
        );

      case 'grep':
        return _SimpleTool(
          toolName: 'Grep',
          input: content.input,
          icon: Icons.find_replace,
        );

      default:
        return _GenericToolMessage(
          toolName: toolName,
          input: content.input,
          icon: Icons.build,
        );
    }
  }
}

/// Edit tool message (shows file path only)
class _EditTool extends StatelessWidget {
  final dynamic input;
  final bool isMulti;

  const _EditTool({required this.input, this.isMulti = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String filePath = '';

    if (input is Map) {
      filePath =
          input['file_path']?.toString() ?? input['path']?.toString() ?? '';
    }

    return ToolContainer(
      toolType: isMulti ? 'MultiEdit' : 'Edit',
      child: Row(
        children: [
          Icon(
            isMulti ? Icons.edit_note : Icons.edit_outlined,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              filePath,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple tool message for glob, grep, etc.
class _SimpleTool extends StatelessWidget {
  final String toolName;
  final dynamic input;
  final IconData icon;

  const _SimpleTool({
    required this.toolName,
    required this.input,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String displayText = '';
    if (input is Map) {
      displayText =
          input['pattern']?.toString() ??
          input['query']?.toString() ??
          input.toString();
    } else {
      displayText = input?.toString() ?? '';
    }

    return ToolContainer(
      toolType: toolName,
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic tool message for unknown tools
class _GenericToolMessage extends StatelessWidget {
  final String toolName;
  final dynamic input;
  final IconData icon;

  const _GenericToolMessage({
    required this.toolName,
    required this.input,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolContainer(
      toolType: toolName,
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              input?.toString() ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
