import 'package:flutter/material.dart';

import '../../../models/model_config.dart';
import '../../compact_selector.dart';
import 'status_dot.dart';

class ProjectChatTopBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefreshPreview;
  final VoidCallback onOpenInNewTab;
  final Color? workspaceDotColor;
  final String? workspaceTooltip;
  final VoidCallback? onWorkspacePressed;
  final List<ModelInfo> models;
  final String selectedModelId;
  final ValueChanged<String>? onModelChanged;
  final bool isModelLoading;
  final bool isModelSwitching;

  const ProjectChatTopBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onRefreshPreview,
    required this.onOpenInNewTab,
    this.workspaceDotColor,
    this.workspaceTooltip,
    this.onWorkspacePressed,
    this.models = const <ModelInfo>[],
    this.selectedModelId = '',
    this.onModelChanged,
    this.isModelLoading = false,
    this.isModelSwitching = false,
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
                  label: null,
                  icon: Icons.preview,
                  onTap: () => onTabSelected(0),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  isSelected: currentIndex == 1,
                  label: null,
                  icon: Icons.code,
                  onTap: () => onTabSelected(1),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  isSelected: currentIndex == 2,
                  label: null,
                  icon: Icons.settings,
                  onTap: () => onTabSelected(2),
                ),
              ],
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 156,
                child: CompactSelector(
                  options: models
                      .map(
                        (m) =>
                            CompactSelectorOption(value: m.id, label: m.name),
                      )
                      .toList(),
                  value: selectedModelId.trim().isEmpty
                      ? null
                      : selectedModelId.trim(),
                  placeholder: 'Model',
                  tooltip: 'Select model',
                  leadingIcon: Icons.auto_awesome_rounded,
                  minWidth: 120,
                  maxWidth: 156,
                  isLoading: isModelLoading || isModelSwitching,
                  onChanged:
                      (isModelLoading ||
                          isModelSwitching ||
                          onModelChanged == null ||
                          models.isEmpty)
                      ? null
                      : (v) => onModelChanged!(v),
                ),
              ),
              const SizedBox(width: 8),
              if (workspaceDotColor != null)
                _ActionIconButton(
                  iconWidget: ProjectChatStatusDot(
                    color: workspaceDotColor!,
                    tooltip: workspaceTooltip ?? 'Workspace',
                  ),
                  onPressed: onWorkspacePressed ?? () {},
                ),
              if (workspaceDotColor != null) const SizedBox(width: 8),
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
  final String? label;
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
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: hasLabel
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.all(10),
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
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onPressed;

  const _ActionIconButton({this.icon, this.iconWidget, required this.onPressed})
    : assert(icon != null || iconWidget != null);

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
            child:
                iconWidget ??
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
