import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import 'project_overview_card_shell.dart';
import 'project_overview_utils.dart';

class ProjectOverviewHeaderCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewHeaderCard({super.key, required this.project});

  String _heroTag(String projectId) => 'project-emoji-$projectId';

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
              Hero(
                tag: _heroTag(project.id),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Color.alphaBlend(
                        colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        colorScheme.surface,
                      ),
                      border: Border.all(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.22 : 0.16,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      project.emoji ?? '🚀',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.projectDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.92,
                        ),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ProjectStatusChip(status: project.status),
              const SizedBox(width: 10),
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                _t(
                  context,
                  'project_overview_header_updated',
                  'Updated {time}',
                ).replaceAll(
                  '{time}',
                  formatTimeAgo(context, project.updatedAt),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.90),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProjectStatusChip extends StatelessWidget {
  final String status;

  const ProjectStatusChip({super.key, required this.status});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  ({Color color, String label}) _style(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case 'active':
        return (
          color: colorScheme.primary,
          label: _t(context, 'project_overview_status_active', 'Active'),
        );
      case 'archived':
        return (
          color: colorScheme.tertiary,
          label: _t(context, 'project_overview_status_archived', 'Archived'),
        );
      case 'draft':
        return (
          color: colorScheme.onSurfaceVariant,
          label: _t(context, 'project_overview_status_draft', 'Draft'),
        );
      default:
        return (color: colorScheme.onSurfaceVariant, label: status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = _style(context, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: s.color.withValues(
          alpha: colorScheme.brightness == Brightness.dark ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.color.withValues(
            alpha: colorScheme.brightness == Brightness.dark ? 0.55 : 0.40,
          ),
        ),
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
