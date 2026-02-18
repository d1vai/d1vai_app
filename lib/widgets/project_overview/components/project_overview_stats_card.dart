import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import '../../../providers/auth_provider.dart';
import 'project_overview_card_shell.dart';
import 'project_overview_utils.dart';

class ProjectOverviewStatsCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewStatsCard({super.key, required this.project});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  String _formatCreatedAt(BuildContext context, String value) {
    if (value.isEmpty) {
      return _t(context, 'project_overview_stats_unknown', 'Unknown');
    }
    try {
      final localeTag = Localizations.localeOf(context).toLanguageTag();
      return DateFormat.yMMMd(localeTag).format(DateTime.parse(value));
    } catch (_) {
      return _t(context, 'project_overview_stats_unknown', 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: _t(context, 'project_overview_stats_created', 'Created'),
              value: _formatCreatedAt(context, project.createdAt),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(context, 'project_overview_stats_owner', 'Owner'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Selector<AuthProvider, String>(
                  selector: (context, authProvider) =>
                      authProvider.user?.email ??
                      _t(context, 'project_overview_stats_unknown', 'Unknown'),
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
                  _t(
                    context,
                    'project_overview_stats_deployment',
                    'Deployment',
                  ),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
              getDeploymentLabel(context, url),
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
            Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.primary),
          ],
        ],
      ),
    );
  }
}
