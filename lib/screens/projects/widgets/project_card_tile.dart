import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import '../../../widgets/card.dart';

class ProjectCardTile extends StatefulWidget {
  final UserProject project;
  final String updatedText;
  final VoidCallback onTap;
  final VoidCallback? onChat;

  const ProjectCardTile({
    super.key,
    required this.project,
    required this.updatedText,
    required this.onTap,
    this.onChat,
  });

  @override
  State<ProjectCardTile> createState() => _ProjectCardTileState();
}

class _ProjectCardTileState extends State<ProjectCardTile>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shineController;

  String _heroTag(String projectId) => 'project-emoji-$projectId';

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  ({Color color, String label, IconData icon}) _statusStyle(
    String status,
    ColorScheme colorScheme,
  ) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'active':
        return (
          color: colorScheme.primary,
          label: loc?.translate('project_overview_status_active') ?? 'Active',
          icon: Icons.check_circle_outline,
        );
      case 'archived':
        return (
          color: colorScheme.tertiary,
          label:
              loc?.translate('project_overview_status_archived') ??
              '😴 Sleeping',
          icon: Icons.archive_outlined,
        );
      case 'draft':
        return (
          color: colorScheme.onSurfaceVariant,
          label: loc?.translate('project_overview_status_draft') ?? 'Draft',
          icon: Icons.edit_note_outlined,
        );
      case 'error':
        return (
          color: colorScheme.error,
          label: loc?.translate('dashboard_workspace_status_error') ?? 'Error',
          icon: Icons.error_outline,
        );
      default:
        return (
          color: colorScheme.onSurfaceVariant,
          label: status,
          icon: Icons.circle_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final status = _statusStyle(project.status, colorScheme);
    final accent = status.color;
    final tags = project.tags.take(3).toList(growable: false);
    final hasPreview = (project.preferredPreviewUrl ?? '').trim().isNotEmpty;
    final hasChatAction = widget.onChat != null;

    final scale = Tween<double>(
      begin: 1,
      end: 0.992,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    final surface = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.05 : 0.03),
      colorScheme.surface,
    );

    return ScaleTransition(
      scale: scale,
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.zero,
        backgroundColor: surface,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap.call();
            },
            onTapDown: (_) {
              _pressController.forward();
              if (!_shineController.isAnimating) {
                _shineController.forward(from: 0);
              }
            },
            onTapCancel: () => _pressController.reverse(),
            onTapUp: (_) => _pressController.reverse(),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Color.alphaBlend(
                                accent.withValues(alpha: isDark ? 0.18 : 0.12),
                                colorScheme.surface,
                              ),
                              border: Border.all(
                                color: accent.withValues(
                                  alpha: isDark ? 0.26 : 0.20,
                                ),
                              ),
                            ),
                            child: Hero(
                              tag: _heroTag(project.id),
                              flightShuttleBuilder:
                                  (
                                    flightContext,
                                    animation,
                                    flightDirection,
                                    fromHeroContext,
                                    toHeroContext,
                                  ) {
                                    return FadeTransition(
                                      opacity: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                      child: toHeroContext.widget,
                                    );
                                  },
                              child: Material(
                                color: Colors.transparent,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        project.emoji ?? '🚀',
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                                    if (hasPreview)
                                      Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.secondary
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 10,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.projectName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  project.projectDescription,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.82),
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StatusPill(
                            label: status.label,
                            icon: status.icon,
                            color: accent,
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags
                              .map((t) => _TagPill(text: t, accent: accent))
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.updatedText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.88,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (hasPreview)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: hasChatAction
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          widget.onChat?.call();
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color.alphaBlend(
                                        colorScheme.secondary.withValues(
                                          alpha: isDark ? 0.16 : 0.12,
                                        ),
                                        colorScheme.surface,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: colorScheme.secondary.withValues(
                                          alpha: isDark ? 0.30 : 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasChatAction
                                              ? Icons.chat_bubble_outline
                                              : Icons.visibility_outlined,
                                          size: 14,
                                          color: colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          hasChatAction ? 'Chat' : 'Preview',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.secondary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accent.withValues(alpha: isDark ? 0.65 : 0.08),
                            colorScheme.secondary.withValues(
                              alpha: isDark ? 0.30 : 0.04,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(
                          _shineController.value,
                        );
                        final opacity = (isDark ? 0.12 : 0.09) * (1 - t);
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset((t - 0.5) * 320, 0),
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                width: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.55),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: isDark ? 0.16 : 0.12),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.34 : 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String text;
  final Color accent;

  const _TagPill({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.10 : 0.08),
      colorScheme.surface,
    );
    final border = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.18 : 0.12),
      colorScheme.outlineVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
