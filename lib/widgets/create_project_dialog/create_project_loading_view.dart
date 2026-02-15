import 'package:flutter/material.dart';

import '../progress_widget.dart';

class CreateProjectLoadingView extends StatelessWidget {
  const CreateProjectLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressWidget(
          tipList: const [
            'Planning project structure...',
            'Setting up integrations...',
            'Finalizing setup...',
          ],
          completed: false,
          preCompleteDuration: Duration(seconds: 100),
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        Text(
          'Creating your project. This can take up to a couple of minutes...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
