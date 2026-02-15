import 'package:flutter/material.dart';

import 'message_skeleton.dart';
import 'quick_actions.dart';

class ChatScreenEmptyState extends StatelessWidget {
  final ValueChanged<String> onQuickAction;

  const ChatScreenEmptyState({super.key, required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = (constraints.maxHeight * 0.48).clamp(0.0, 420.0);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH, maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy,
                  size: 44.0,
                  color: theme.colorScheme.primary.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask AI',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask about this project or paste code.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.9,
                    ),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                QuickActions(
                  onSelect: onQuickAction,
                  dense: true,
                  showTitle: false,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatScreenLoadingState extends StatelessWidget {
  const ChatScreenLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: const [
          MessageSkeleton(isUser: true, delay: 0),
          MessageSkeleton(isUser: false, delay: 150),
          MessageSkeleton(isUser: true, delay: 300),
        ],
      ),
    );
  }
}
