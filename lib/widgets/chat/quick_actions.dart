import 'package:flutter/material.dart';

/// Quick action buttons for chat screen
class QuickActions extends StatelessWidget {
  final Function(String) onSelect;
  final bool dense;
  final bool showTitle;
  final EdgeInsetsGeometry padding;

  const QuickActions({
    super.key,
    required this.onSelect,
    this.dense = false,
    this.showTitle = true,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _QuickActionChip(
        label: dense ? 'Debug' : 'Help me debug',
        icon: Icons.bug_report,
        dense: dense,
        onTap: () => onSelect('Help me debug my code'),
      ),
      _QuickActionChip(
        label: dense ? 'Explain' : 'Explain code',
        icon: Icons.code,
        dense: dense,
        onTap: () => onSelect('Explain this code to me'),
      ),
      _QuickActionChip(
        label: dense ? 'Optimize' : 'Optimize',
        icon: Icons.speed,
        dense: dense,
        onTap: () => onSelect('How can I optimize this?'),
      ),
      _QuickActionChip(
        label: dense ? 'Best' : 'Best practices',
        icon: Icons.star,
        dense: dense,
        onTap: () => onSelect('What are the best practices for this?'),
      ),
    ];

    return Container(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle) ...[
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: dense ? 8.0 : 12.0),
          ],
          if (dense)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            )
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dense;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: dense ? 16.0 : 18.0),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: dense ? 12 : null,
        fontWeight: dense ? FontWeight.w600 : null,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      padding: dense ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6) : null,
    );
  }
}
