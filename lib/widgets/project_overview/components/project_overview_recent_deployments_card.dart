import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/deployment.dart';
import 'project_overview_card_shell.dart';
import 'project_overview_utils.dart';

class ProjectOverviewRecentDeploymentsCard extends StatelessWidget {
  final List<DeploymentHistory> deployments;
  final bool isLoading;

  const ProjectOverviewRecentDeploymentsCard({
    super.key,
    required this.deployments,
    required this.isLoading,
  });

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ProjectOverviewCardShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rocket_launch_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _t(
                  context,
                  'project_overview_recent_deployments_title',
                  'Recent deployments',
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                    colorScheme.surface,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.28 : 0.18,
                    ),
                  ),
                ),
                child: Text(
                  _t(
                    context,
                    'project_overview_recent_deployments_feed',
                    'Activity feed',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (deployments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _t(
                  context,
                  'project_overview_recent_deployments_empty',
                  'No recent deployments — ship a new build to see activity here.',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...deployments.map((deployment) {
              final timestamp =
                  deployment.completedAt ??
                  deployment.startedAt ??
                  deployment.createdAt ??
                  '';

              Color statusColor;
              if (deployment.status == 'success') {
                statusColor = colorScheme.primary;
              } else if (deployment.status == 'pending') {
                statusColor = colorScheme.tertiary;
              } else {
                statusColor = colorScheme.error;
              }

              final summary =
                  '${_t(context, 'project_overview_recent_deployments_env', '{env} deployment').replaceAll('{env}', deployment.environmentLabel)} • ${deployment.statusLabel} • ${formatTimeAgo(context, timestamp)}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    statusColor.withValues(alpha: isDark ? 0.08 : 0.035),
                    colorScheme.surface,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: isDark ? 0.24 : 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.24 : 0.18,
                          ),
                        ),
                      ),
                      child: Icon(
                        deployment.status == 'success'
                            ? Icons.check_rounded
                            : deployment.status == 'pending'
                            ? Icons.schedule_rounded
                            : Icons.close_rounded,
                        size: 14,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
