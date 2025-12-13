import 'package:flutter/material.dart';

class NoPreviewAvailableView extends StatelessWidget {
  const NoPreviewAvailableView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.preview,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('No Preview Available', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Deploy your project to see a preview',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
