import 'package:flutter/material.dart';

import '../../../models/deployment.dart';
import 'project_overview_utils.dart';
import 'project_overview_card_shell.dart';

class ProjectOverviewRecentDeploymentsCard extends StatelessWidget {
  final List<DeploymentHistory> deployments;
  final bool isLoading;

  const ProjectOverviewRecentDeploymentsCard({
    super.key,
    required this.deployments,
    required this.isLoading,
  });

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
                'Recent deployments',
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
                  'Activity feed',
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
                'No recent deployments — ship a new build to see activity here.',
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

              final itemSurface = Color.alphaBlend(
                colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.02),
                colorScheme.surface,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: itemSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(
                      alpha: isDark ? 0.30 : 0.36,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.24 : 0.18,
                          ),
                        ),
                      ),
                      child: Icon(
                        deployment.status == 'success'
                            ? Icons.check_circle_outline
                            : deployment.status == 'pending'
                            ? Icons.hourglass_bottom_rounded
                            : Icons.error_outline,
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${deployment.environment} deployment',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                formatTimeAgo(timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            deployment.statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
