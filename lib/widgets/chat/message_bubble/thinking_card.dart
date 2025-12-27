import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expandable_text.dart';
import 'message_card_base.dart';

class ChatThinkingCard extends StatelessWidget {
  final String text;

  const ChatThinkingCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChatMessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: Icons.psychology_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Thinking',
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied thinking'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            copyLabel: 'Copy thinking',
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: text,
            maxLines: 4,
            isMarkdown: false,
            expandText: 'Show more',
            collapseText: 'Show less',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.3,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

