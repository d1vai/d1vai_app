import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/project.dart';
import '../../../providers/auth_provider.dart';
import 'project_overview_utils.dart';
import 'project_overview_card_shell.dart';

class ProjectOverviewStatsCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewStatsCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: 'Created',
              value: project.createdAt.isNotEmpty
                  ? DateFormat('MMM d, yyyy').format(DateTime.parse(project.createdAt))
                  : 'Unknown',
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owner',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Selector<AuthProvider, String>(
                  selector: (context, authProvider) =>
                      authProvider.user?.email ?? 'Unknown',
                  builder: (context, email, child) {
                    return Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deployment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ProjectDeploymentLink(url: project.latestPreviewUrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class ProjectDeploymentLink extends StatelessWidget {
  final String? url;

  const ProjectDeploymentLink({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        if (url == null || url!.isEmpty) return;
        final uri = Uri.tryParse(url!);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              getDeploymentLabel(url),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: url != null && url!.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (url != null && url!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}
