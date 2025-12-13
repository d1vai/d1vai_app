import 'package:flutter/material.dart';

class ProjectChatTopBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefreshPreview;
  final VoidCallback onOpenInNewTab;

  const ProjectChatTopBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onRefreshPreview,
    required this.onOpenInNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _TabButton(
                  isSelected: currentIndex == 0,
                  label: 'Preview',
                  icon: Icons.preview,
                  onTap: () => onTabSelected(0),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  isSelected: currentIndex == 1,
                  label: 'Code',
                  icon: Icons.code,
                  onTap: () => onTabSelected(1),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  isSelected: currentIndex == 2,
                  label: 'Env',
                  icon: Icons.settings,
                  onTap: () => onTabSelected(2),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _ActionIconButton(
                icon: Icons.restart_alt,
                onPressed: onRefreshPreview,
              ),
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.open_in_new,
                onPressed: onOpenInNewTab,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final bool isSelected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TabButton({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
