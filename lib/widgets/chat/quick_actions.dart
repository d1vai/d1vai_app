import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick action buttons for chat screen
class QuickActionItem {
  final String label;
  final IconData icon;
  final String prompt;

  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.prompt,
  });
}

class QuickActions extends StatefulWidget {
  final Function(String) onSelect;
  final List<QuickActionItem>? actions;
  final String? title;
  final bool dense;
  final bool showTitle;
  final EdgeInsetsGeometry padding;
  final bool animateIn;
  final bool enableBreathing;

  const QuickActions({
    super.key,
    required this.onSelect,
    this.actions,
    this.title,
    this.dense = false,
    this.showTitle = true,
    this.padding = const EdgeInsets.all(16.0),
    this.animateIn = true,
    this.enableBreathing = true,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (widget.animateIn) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant QuickActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateIn != oldWidget.animateIn) {
      if (widget.animateIn) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items =
        widget.actions ??
        const <QuickActionItem>[
          QuickActionItem(
            label: 'Help me debug',
            icon: Icons.bug_report,
            prompt: 'Help me debug my code',
          ),
          QuickActionItem(
            label: 'Explain code',
            icon: Icons.code,
            prompt: 'Explain this code to me',
          ),
          QuickActionItem(
            label: 'Optimize',
            icon: Icons.speed,
            prompt: 'How can I optimize this?',
          ),
          QuickActionItem(
            label: 'Best practices',
            icon: Icons.star,
            prompt: 'What are the best practices for this?',
          ),
        ];
    final actions = items.map((item) {
      final label = widget.dense
          ? item.label.split(' ').take(2).join(' ')
          : item.label;
      return _QuickActionChip(
        label: label,
        icon: item.icon,
        dense: widget.dense,
        enableBreathing: widget.enableBreathing,
        onTap: () => widget.onSelect(item.prompt),
      );
    }).toList();

    final title = widget.showTitle
        ? Text(
            widget.title ?? 'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          )
        : null;

    final content = widget.dense
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _StaggeredIn(
                    controller: _controller,
                    index: i,
                    count: actions.length,
                    child: actions[i],
                  ),
                ],
              ],
            ),
          )
        : Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < actions.length; i++)
                _StaggeredIn(
                  controller: _controller,
                  index: i,
                  count: actions.length,
                  child: actions[i],
                ),
            ],
          );

    return Container(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            _StaggeredIn(
              controller: _controller,
              index: 0,
              count: 1,
              child: title,
            ),
            SizedBox(height: widget.dense ? 8.0 : 12.0),
          ],
          content,
        ],
      ),
    );
  }
}

class _StaggeredIn extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int count;
  final Widget child;

  const _StaggeredIn({
    required this.controller,
    required this.index,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / (count + 2)).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
          ),
        );
      },
    );
  }
}

class _QuickActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dense;
  final bool enableBreathing;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.dense,
    required this.enableBreathing,
  });

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  late final AnimationController _breathController;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _pressScale = Tween<double>(
      begin: 1,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breath = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    if (widget.enableBreathing) {
      _breathController.repeat(reverse: true);
    } else {
      _breathController.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _QuickActionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableBreathing != widget.enableBreathing) {
      if (widget.enableBreathing) {
        _breathController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _breathController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final baseBg = colorScheme.surfaceContainerHighest;
    final accent = colorScheme.primary;
    final breatheT = widget.enableBreathing ? _breath.value : 0.0;
    final glow = accent.withValues(alpha: 0.06 + 0.06 * breatheT);
    final border = Color.alphaBlend(
      accent.withValues(alpha: 0.10 + 0.10 * breatheT),
      colorScheme.outlineVariant,
    );

    final isDense = widget.dense;
    final avatarSize = isDense ? 16.0 : 18.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_pressController, _breathController]),
      builder: (context, _) {
        return Transform.scale(
          scale: _pressScale.value,
          child: Container(
            decoration: BoxDecoration(
              color: Color.alphaBlend(glow, baseBg),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              boxShadow: widget.enableBreathing
                  ? [
                      BoxShadow(
                        color: glow,
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTap();
                },
                onTapDown: (_) => _pressController.forward(),
                onTapCancel: () => _pressController.reverse(),
                onTapUp: (_) => _pressController.reverse(),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: isDense
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      : const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: avatarSize,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.9,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: isDense ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
