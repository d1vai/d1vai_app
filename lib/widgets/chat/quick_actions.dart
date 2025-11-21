import 'package:flutter/material.dart';

/// Quick action buttons for chat screen
class QuickActions extends StatelessWidget {
  final Function(String) onSelect;

  const QuickActions({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              _QuickActionChip(
                label: 'Help me debug',
                icon: Icons.bug_report,
                onTap: () => onSelect('Help me debug my code'),
              ),
              _QuickActionChip(
                label: 'Explain code',
                icon: Icons.code,
                onTap: () => onSelect('Explain this code to me'),
              ),
              _QuickActionChip(
                label: 'Optimize',
                icon: Icons.speed,
                onTap: () => onSelect('How can I optimize this?'),
              ),
              _QuickActionChip(
                label: 'Best practices',
                icon: Icons.star,
                onTap: () => onSelect('What are the best practices for this?'),
              ),
            ],
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

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18.0),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
