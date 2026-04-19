import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('chooser'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how you want to start',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        CreateProjectOptionCard(
          icon: Icons.auto_awesome,
          title: 'New project (AI)',
          subtitle: 'Describe what you want to build and we set up everything.',
          badgeText: 'Recommended',
          badgeColor: theme.colorScheme.primary,
          attention: true,
          onTap: disabled ? null : onChooseNewAi,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.archive_outlined,
          title: 'Import local zip',
          subtitle:
              'Upload a local .zip project archive and import it directly.',
          onTap: disabled ? null : onChooseImportLocal,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.public,
          title: 'Import public repo',
          subtitle: 'Mirror a public GitHub repo into the org workspace.',
          onTap: disabled ? null : onChooseImportPublic,
        ),
        const SizedBox(height: 10),
        CreateProjectOptionCard(
          icon: Icons.hub,
          title: 'Import from GitHub (collaborator)',
          subtitle:
              'Guided import: add bot → accept invite → verify access → import.',
          onTap: disabled ? null : onChooseGithubCollaborator,
        ),
      ],
    );
  }
}
