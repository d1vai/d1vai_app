import 'package:flutter/material.dart';

import '../../../models/project.dart';
import 'project_overview_utils.dart';

class ProjectOverviewHeaderCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewHeaderCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    project.emoji ?? '🚀',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.projectName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.projectDescription,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ProjectStatusChip(status: project.status),
                const SizedBox(width: 8),
                Text(
                  'Updated ${formatTimeAgo(project.updatedAt)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectStatusChip extends StatelessWidget {
  final String status;

  const ProjectStatusChip({super.key, required this.status});

  ({Color color, String label}) _style(ColorScheme colorScheme) {
    switch (status) {
      case 'active':
        return (color: colorScheme.primary, label: 'Active');
      case 'archived':
        return (color: colorScheme.tertiary, label: 'Archived');
      case 'draft':
        return (color: colorScheme.onSurfaceVariant, label: 'Draft');
      default:
        return (color: colorScheme.onSurfaceVariant, label: status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = _style(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withValues(alpha: 0.55)),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          color: s.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

