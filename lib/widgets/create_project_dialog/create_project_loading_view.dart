import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../progress_widget.dart';

class CreateProjectLoadingView extends StatelessWidget {
  const CreateProjectLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressWidget(
          tipList: [
            loc?.translate('create_project_loading_step_plan') ??
                'Planning project structure...',
            loc?.translate('create_project_loading_step_integrations') ??
                'Setting up integrations...',
            loc?.translate('create_project_loading_step_finalize') ??
                'Finalizing setup...',
          ],
          completed: false,
          preCompleteDuration: Duration(seconds: 100),
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        Text(
          loc?.translate('create_project_loading_message') ??
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
