import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';

class ProjectCardTile extends StatefulWidget {
  final UserProject project;
  final String updatedText;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;

  const ProjectCardTile({
    super.key,
    required this.project,
    required this.updatedText,
    required this.onTap,
    this.onOpenChat,
  });

  @override
  State<ProjectCardTile> createState() => _ProjectCardTileState();
}

class _ProjectCardTileState extends State<ProjectCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;

  String _heroTag(String projectId) => 'project-emoji-$projectId';

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  ({Color color, String label}) _statusStyle(
    String status,
    ColorScheme colorScheme,
  ) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'active':
        return (
          color: colorScheme.secondary,
          label: loc?.translate('project_overview_status_active') ?? 'Active',
        );
      case 'archived':
        return (
          color: colorScheme.onSurfaceVariant,
          label:
              loc?.translate('project_overview_status_archived') ?? 'Archived',
        );
      case 'draft':
        return (
          color: colorScheme.onSurfaceVariant,
          label: loc?.translate('project_overview_status_draft') ?? 'Draft',
        );
      case 'error':
        return (
          color: colorScheme.error,
          label: loc?.translate('dashboard_workspace_status_error') ?? 'Error',
        );
      default:
        return (color: colorScheme.onSurfaceVariant, label: status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final status = _statusStyle(project.status, colorScheme);
    final tags = project.tags.take(2).toList(growable: false);
    final scale = Tween<double>(begin: 1, end: 0.988).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );

    return ScaleTransition(
      scale: scale,
      child: Material(
        color: colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.70 : 0.82,
            ),
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => _pressController.forward(),
          onTapCancel: () => _pressController.reverse(),
          onTapUp: (_) => _pressController.reverse(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: _heroTag(project.id),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.58 : 0.72,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        project.emoji ?? '🚀',
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.projectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ProjectStatus(
                            label: status.label,
                            color: status.color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        project.projectDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              widget.updatedText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tags.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Chat with AI',
                            child: IconButton(
                              onPressed: widget.onOpenChat ?? widget.onTap,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.primaryContainer
                                    .withValues(alpha: isDark ? 0.34 : 0.7),
                                foregroundColor: colorScheme.onPrimaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              icon: const Icon(
                                Icons.terminal_rounded,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _ProjectStatus({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
