import 'package:flutter/material.dart';
import '../../../models/message.dart';
import 'bash_tool.dart';
import 'write_tool.dart';
import 'read_tool.dart';
import 'tool_container.dart';

/// Enhanced tool message renderer with specialized components for different tool types
class EnhancedToolMessage extends StatelessWidget {
  final ToolMessageContent content;

  const EnhancedToolMessage({
    super.key,
    required this.content,
  });

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
        return _GenericToolMessage(
          toolName: 'Edit',
          input: content.input,
          icon: Icons.edit,
        );
      
      case 'multi_edit':
        return _GenericToolMessage(
          toolName: 'MultiEdit',
          input: content.input,
          icon: Icons.content_copy,
        );
      
      case 'glob':
        return _GenericToolMessage(
          toolName: 'Glob',
          input: content.input,
          icon: Icons.search,
        );
      
      case 'grep':
        return _GenericToolMessage(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tool: $toolName',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
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
              input?.toString() ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
