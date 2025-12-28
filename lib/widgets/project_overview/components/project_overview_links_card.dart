import 'package:flutter/material.dart';

import '../../../models/project.dart';
import 'project_overview_card_shell.dart';

class ProjectOverviewLinksCard extends StatelessWidget {
  final UserProject project;
  final Future<void> Function(String url) onOpenPreviewUrl;
  final Future<void> Function(String repoName) onOpenGitHubRepo;

  const ProjectOverviewLinksCard({
    super.key,
    required this.project,
    required this.onOpenPreviewUrl,
    required this.onOpenGitHubRepo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProjectOverviewCardShell(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Icon(Icons.language, color: theme.colorScheme.primary),
            title: const Text('Preview URL'),
            subtitle: Text(project.latestPreviewUrl ?? 'Not available'),
            trailing: Icon(
              Icons.open_in_new,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              final url = project.latestPreviewUrl;
              if (url != null && url.isNotEmpty) {
                onOpenPreviewUrl(url);
              }
            },
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Icon(Icons.code, color: theme.colorScheme.primary),
            title: const Text('GitHub Repository'),
            subtitle: Text('proj_${project.projectPort}'),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              onOpenGitHubRepo('proj_${project.projectPort}');
            },
          ),
        ],
      ),
    );
  }
}
