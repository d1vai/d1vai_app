import 'package:flutter/material.dart';

import '../../../models/project.dart';

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
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Preview URL'),
            subtitle: Text(project.latestPreviewUrl ?? 'Not available'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              final url = project.latestPreviewUrl;
              if (url != null && url.isNotEmpty) {
                onOpenPreviewUrl(url);
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub Repository'),
            subtitle: Text('proj_${project.projectPort}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              onOpenGitHubRepo('proj_${project.projectPort}');
            },
          ),
        ],
      ),
    );
  }
}

