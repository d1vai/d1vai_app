import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';

class ProjectCardTile extends StatefulWidget {
  final UserProject project;
  final String updatedText;
  final VoidCallback onTap;
  final VoidCallback? onOpenTerminal;
  final VoidCallback? onOpenChat;

  const ProjectCardTile({
    super.key,
    required this.project,
    required this.updatedText,
    required this.onTap,
    this.onOpenTerminal,
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
      duration: const Duration(milliseconds: 105),
      reverseDuration: const Duration(milliseconds: 240),
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
    final loc = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = _statusStyle(project.status, colorScheme);
    final branch =
        (project.workspaceCurrentBranch ??
                project.repositoryCurrentBranch ??
                project.repositoryDefaultBranch ??
                '')
            .trim();
    final hasProduction =
        (project.latestProdDeploymentUrl ?? '').trim().isNotEmpty ||
        (project.vercelProdDomain ?? '').trim().isNotEmpty;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeOutBack,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pressAnimation,
        builder: (context, child) {
          final progress = reduceMotion ? 0.0 : pressAnimation.value;
          return Transform.translate(
            key: ValueKey('project-card-motion-${project.id}'),
            offset: Offset(0, 1.8 * progress),
            child: Transform.scale(
              key: ValueKey('project-card-scale-${project.id}'),
              scale: 1 - (0.024 * progress),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: Material(
          color: colorScheme.surfaceContainerLow,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: _heroTag(project.id),
                        transitionOnUserGestures: true,
                        createRectTween: (begin, end) =>
                            MaterialRectCenterArcTween(begin: begin, end: end),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: isDark ? 0.58 : 0.72),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              project.emoji ?? '📦',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.projectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              project.projectDescription.isEmpty
                                  ? (branch.isEmpty
                                        ? 'Project workspace'
                                        : branch)
                                  : project.projectDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            loc?.translate('terminal_action_open') ??
                            'Open terminal',
                        child: IconButton(
                          key: ValueKey('project-terminal-${project.id}'),
                          onPressed: widget.onOpenTerminal ?? widget.onTap,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: const Icon(Icons.terminal_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Tooltip(
                        message: loc?.translate('chat') ?? 'Chat',
                        child: IconButton(
                          key: ValueKey('project-chat-${project.id}'),
                          onPressed: widget.onOpenChat ?? widget.onTap,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ProjectStatus(label: status.label, color: status.color),
                      const SizedBox(width: 10),
                      _ProjectPill(
                        label: hasProduction ? 'Production' : 'Development',
                        color: hasProduction
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.updatedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (project.analyticsEnabled == true ||
                      project.hasDatabaseEnabled ||
                      project.hasPaymentEnabled ||
                      branch.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (project.analyticsEnabled == true)
                          const _ProjectCapability(
                            icon: Icons.bar_chart_rounded,
                            label: 'Analytics',
                          ),
                        if (project.hasDatabaseEnabled)
                          const _ProjectCapability(
                            icon: Icons.storage_rounded,
                            label: 'Database',
                          ),
                        if (project.hasPaymentEnabled)
                          const _ProjectCapability(
                            icon: Icons.credit_card_rounded,
                            label: 'Payments',
                          ),
                        if (branch.isNotEmpty)
                          _ProjectCapability(
                            icon: Icons.account_tree_outlined,
                            label: branch,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
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

class _ProjectPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ProjectPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProjectCapability extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProjectCapability({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
    );
  }
}
