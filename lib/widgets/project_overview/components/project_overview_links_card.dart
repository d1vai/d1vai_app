import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import '../../../utils/preview_url.dart';
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

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = preferredPreviewUrlFromProject(project);
    return ProjectOverviewCardShell(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Icon(Icons.language, color: theme.colorScheme.primary),
            title: Text(
              _t(context, 'project_overview_links_preview_url', 'Preview URL'),
            ),
            subtitle: Text(
              previewUrl ??
                  _t(
                    context,
                    'project_overview_links_not_available',
                    'Not available',
                  ),
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              final url = previewUrl;
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
            title: Text(
              _t(
                context,
                'project_overview_links_github_repo',
                'GitHub Repository',
              ),
            ),
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
