import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import 'project_overview_card_shell.dart';
import 'project_overview_utils.dart';

class ProjectOverviewHealthMetricsCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewHealthMetricsCard({super.key, required this.project});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledLabel = _t(
      context,
      'project_overview_health_status_enabled',
      'Enabled',
    );
    final disabledLabel = _t(
      context,
      'project_overview_health_status_disabled',
      'Disabled',
    );
    final initializingLabel = _t(
      context,
      'project_overview_health_status_initializing',
      'Initializing',
    );

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(context, 'project_overview_health_title', 'Health metrics'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          _HealthMetricItem(
            title: _t(context, 'project_overview_health_branch', 'Branch'),
            status:
                (project.workspaceCurrentBranch ??
                project.repositoryCurrentBranch ??
                '—'),
            description: _t(
              context,
              'project_overview_health_branch_desc',
              'Active workspace/repository branch',
            ),
            icon: Icons.alt_route,
            isEnabled:
                (project.workspaceCurrentBranch ??
                        project.repositoryCurrentBranch)
                    ?.trim()
                    .isNotEmpty ==
                true,
            badgeMonospace: true,
          ),
          const Divider(height: 32),
          _HealthMetricItem(
            title: _t(
              context,
              'project_overview_health_prod_domain',
              'Production domain',
            ),
            status: getDeploymentLabel(
              context,
              project.latestProdDeploymentUrl?.trim().isNotEmpty == true
                  ? project.latestProdDeploymentUrl
                  : project.vercelProdDomain,
            ),
            description: null,
            icon: Icons.language,
            isEnabled:
                project.latestProdDeploymentUrl != null &&
                project.latestProdDeploymentUrl!.isNotEmpty,
            statusOnNewLine: true,
          ),
          const Divider(height: 32),
          _HealthMetricItem(
            title: _t(
              context,
              'project_overview_health_analytics',
              'Analytics status',
            ),
            status: project.hasAnalyticsId
                ? enabledLabel
                : project.analyticsEnabled == true
                ? initializingLabel
                : disabledLabel,
            description: _t(
              context,
              'project_overview_health_analytics_desc',
              'Traffic instrumentation',
            ),
            icon: Icons.analytics,
            isEnabled: project.hasAnalyticsId,
          ),
          const Divider(height: 32),
          _HealthMetricItem(
            title: _t(context, 'project_overview_health_database', 'Database'),
            status: project.hasDatabaseEnabled ? enabledLabel : disabledLabel,
            description: _t(
              context,
              'project_overview_health_database_desc',
              'Neon integration',
            ),
            icon: Icons.storage,
            isEnabled: project.hasDatabaseEnabled,
          ),
          const Divider(height: 32),
          _HealthMetricItem(
            title: _t(context, 'project_overview_health_payments', 'Payments'),
            status: project.projectPayId != null ? enabledLabel : disabledLabel,
            description: _t(
              context,
              'project_overview_health_payments_desc',
              'User-scoped Pay API',
            ),
            icon: Icons.payment,
            isEnabled: project.projectPayId != null,
          ),
        ],
      ),
    );
  }
}

class _HealthMetricItem extends StatelessWidget {
  final String title;
  final String status;
  final String? description;
  final IconData icon;
  final bool isEnabled;
  final bool badgeMonospace;
  final bool statusOnNewLine;

  const _HealthMetricItem({
    required this.title,
    required this.status,
    this.description,
    required this.icon,
    required this.isEnabled,
    this.badgeMonospace = false,
    this.statusOnNewLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Web parity: outline badge with subtle tint when enabled.
    final badgeBg = isEnabled
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            theme.colorScheme.surface,
          )
        : theme.colorScheme.surface;
    final badgeBorder = isEnabled
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.30 : 0.22),
            theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          )
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.8);
    final badgeFg = isEnabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.92)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.92);
    final hasDescription =
        description != null && description!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!statusOnNewLine)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: badgeMonospace ? 'monospace' : null,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (hasDescription) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: badgeMonospace ? 'monospace' : null,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
