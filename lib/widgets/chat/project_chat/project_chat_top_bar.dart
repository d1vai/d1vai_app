import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/model_config.dart';
import '../../compact_selector.dart';
import 'chat_engine_mode.dart';
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
  final ChatEngineMode selectedEngineMode;
  final ValueChanged<String>? onModelChanged;
  final ValueChanged<ChatEngineMode>? onEngineChanged;
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
    this.selectedEngineMode = ChatEngineMode.thinkHard,
    this.onModelChanged,
    this.onEngineChanged,
    this.isModelLoading = false,
    this.isModelSwitching = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final fastHint =
        loc?.translate('project_chat_engine_fast_hint') ??
        'Fast mode uses Claude engine';
    final thinkHardHint =
        loc?.translate('project_chat_engine_think_hard_hint') ??
        'Think Hard mode uses Codex engine';

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
              _EngineModeSegment(
                value: selectedEngineMode,
                fastTooltip: fastHint,
                thinkHardTooltip: thinkHardHint,
                onChanged:
                    (isModelLoading || isModelSwitching || onEngineChanged == null)
                    ? null
                    : onEngineChanged,
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

class _EngineModeSegment extends StatelessWidget {
  final ChatEngineMode value;
  final String fastTooltip;
  final String thinkHardTooltip;
  final ValueChanged<ChatEngineMode>? onChanged;

  const _EngineModeSegment({
    required this.value,
    required this.fastTooltip,
    required this.thinkHardTooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFast = value == ChatEngineMode.fast;
    final tooltip = isFast ? fastTooltip : thinkHardTooltip;
    final borderColor = isFast
        ? Colors.green.withValues(alpha: 0.42)
        : theme.colorScheme.primary.withValues(alpha: 0.36);
    final backgroundColor = isFast
        ? Colors.green.withValues(alpha: 0.1)
        : theme.colorScheme.primary.withValues(alpha: 0.1);
    final badgeColor = isFast ? Colors.green : theme.colorScheme.primary;
    final iconColor = isFast
        ? Colors.green.shade700
        : theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: isFast,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onChanged == null
                ? null
                : () => onChanged!(
                    isFast ? ChatEngineMode.thinkHard : ChatEngineMode.fast,
                  ),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.14),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFast ? Icons.flash_on_rounded : Icons.psychology_rounded,
                      size: 11,
                      color: isFast ? Colors.green.shade900 : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isFast ? Icons.psychology_alt_rounded : Icons.flash_on_rounded,
                    size: 14,
                    color: iconColor.withValues(alpha: isFast ? 0.72 : 0.82),
                  ),
                ],
              ),
            ),
          ),
        ),
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
