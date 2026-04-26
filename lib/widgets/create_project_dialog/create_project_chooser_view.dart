import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'create_project_option_card.dart';

class CreateProjectChooserView extends StatelessWidget {
  final bool disabled;
  final VoidCallback onChooseNewAi;
  final VoidCallback onChooseImportLocal;
  final VoidCallback onChooseImportPublic;
  final VoidCallback onChooseGithubCollaborator;

  const CreateProjectChooserView({
    super.key,
    required this.disabled,
    required this.onChooseNewAi,
    required this.onChooseImportLocal,
    required this.onChooseImportPublic,
    required this.onChooseGithubCollaborator,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('chooser'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc?.translate('create_project_choose_how_start') ??
              'Choose how you want to start',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        CreateProjectOptionCard(
          icon: Icons.auto_awesome,
          title:
              loc?.translate('create_project_new_ai_title') ??
              'New project (AI)',
          subtitle:
              loc?.translate('create_project_new_ai_subtitle') ??
              'Describe what you want to build and we set up everything.',
          badgeText: loc?.translate('recommended') ?? 'Recommended',
          badgeColor: theme.colorScheme.primary,
          attention: true,
          onTap: disabled ? null : onChooseNewAi,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.archive_outlined,
          title:
              loc?.translate('create_project_import_local_title') ??
              'Import local zip',
          subtitle:
              loc?.translate('create_project_import_local_subtitle') ??
              'Upload a local .zip project archive and import it directly.',
          onTap: disabled ? null : onChooseImportLocal,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.public,
          title:
              loc?.translate('create_project_import_public_title') ??
              'Import public repo',
          subtitle:
              loc?.translate('create_project_import_public_subtitle') ??
              'Mirror a public GitHub repo into the org workspace.',
          onTap: disabled ? null : onChooseImportPublic,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.hub,
          title:
              loc?.translate('create_project_github_collaborator_title') ??
              'Import from GitHub (collaborator)',
          subtitle:
              loc?.translate('create_project_github_collaborator_subtitle') ??
              'Guided import: add bot → accept invite → verify access → import.',
          onTap: disabled ? null : onChooseGithubCollaborator,
        ),
      ],
    );
  }
}
