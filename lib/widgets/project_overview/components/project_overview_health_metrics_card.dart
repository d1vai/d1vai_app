import 'package:flutter/material.dart';

import '../../../models/project.dart';

class ProjectOverviewHealthMetricsCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewHealthMetricsCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _HealthMetricItem(
              title: 'Branch',
              status:
                  (project.workspaceCurrentBranch ??
                      project.repositoryCurrentBranch ??
                      '—'),
              description: 'Active workspace/repository branch',
              icon: Icons.alt_route,
              isEnabled:
                  (project.workspaceCurrentBranch ??
                          project.repositoryCurrentBranch)
                      ?.trim()
                      .isNotEmpty ==
                  true,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Production domain',
              status: project.latestProdDeploymentUrl != null &&
                      project.latestProdDeploymentUrl!.isNotEmpty
                  ? project.latestProdDeploymentUrl!
                  : (project.vercelProdDomain != null &&
                          project.vercelProdDomain!.isNotEmpty
                      ? project.vercelProdDomain!
                      : '—'),
              description: project.latestProdDeploymentUrl != null &&
                      project.latestProdDeploymentUrl!.isNotEmpty
                  ? 'Primary public endpoint'
                  : 'No domain configured',
              icon: Icons.language,
              isEnabled: project.latestProdDeploymentUrl != null &&
                  project.latestProdDeploymentUrl!.isNotEmpty,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Analytics status',
              status: (project.analyticsId != null &&
                          project.analyticsId!.trim().isNotEmpty) ||
                      project.analyticsEnabled == true
                  ? 'Enabled'
                  : 'Disabled',
              description: 'Traffic instrumentation',
              icon: Icons.analytics,
              isEnabled: (project.analyticsId != null &&
                      project.analyticsId!.trim().isNotEmpty) ||
                  project.analyticsEnabled == true,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Database',
              status:
                  (project.projectDatabaseId != null &&
                          project.projectDatabaseId! > 0)
                      ? 'Enabled'
                      : 'Disabled',
              description: 'Neon integration',
              icon: Icons.storage,
              isEnabled:
                  project.projectDatabaseId != null &&
                  project.projectDatabaseId! > 0,
            ),
            const Divider(height: 32),
            _HealthMetricItem(
              title: 'Payments',
              status: project.projectPayId != null ? 'Enabled' : 'Disabled',
              description: 'User-scoped Pay API',
              icon: Icons.payment,
              isEnabled: project.projectPayId != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthMetricItem extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final IconData icon;
  final bool isEnabled;

  const _HealthMetricItem({
    required this.title,
    required this.status,
    required this.description,
    required this.icon,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

