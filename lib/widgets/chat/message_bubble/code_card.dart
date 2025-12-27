import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../code_highlight_block.dart';
import 'message_card_base.dart';

class ChatCodeCard extends StatelessWidget {
  final String code;
  final bool isToolResult;

  const ChatCodeCard({
    super.key,
    required this.code,
    required this.isToolResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = chatSuccessTint(theme);
    final bg = isToolResult
        ? successTint.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
          )
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final title = isToolResult ? 'Tool execution result' : 'Code';
    final iconColor = isToolResult ? successTint : theme.colorScheme.primary;

    return ChatMessageCard(
      backgroundColor: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: Icons.code,
            iconColor: iconColor,
            title: title,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            copyLabel: 'Copy code',
          ),
          const SizedBox(height: 8),
          if (isToolResult)
            RepaintBoundary(
              child: CodeHighlightBlock(
                text: code,
                terminalStyle: true,
                maxVisibleLines: 12,
              ),
            )
          else
            ChatExpandableSelectableBlock(
              text: code,
              collapsedLines: 6,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.25,
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }
}

