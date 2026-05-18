import 'package:flutter/material.dart';

import '../../../models/model_config.dart';
import '../../compact_selector.dart';
import 'chat_engine_mode.dart';

class ProjectChatTopBar extends StatelessWidget {
  final int currentIndex;
  final String? previewUrl;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefreshPreview;
  final VoidCallback onOpenInNewTab;

  const ProjectChatTopBar({
    super.key,
    required this.currentIndex,
    this.previewUrl,
    required this.onTabSelected,
    required this.onRefreshPreview,
    required this.onOpenInNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedPreviewUrl = previewUrl?.trim() ?? '';
    final showPreviewMeta = currentIndex == 0 && trimmedPreviewUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final tabRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabButton(
                      isSelected: currentIndex == 0,
                      label: compact ? 'Prev' : null,
                      icon: Icons.remove_red_eye_outlined,
                      onTap: () => onTabSelected(0),
                    ),
                    if (showPreviewMeta) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _PreviewInlineMeta(url: trimmedPreviewUrl),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _TabButton(
                  isSelected: currentIndex == 1,
                  label: 'Files',
                  icon: Icons.folder_outlined,
                  onTap: () => onTabSelected(1),
                ),
              ),
            ],
          );
          final actionsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIconButton(
                icon: Icons.restart_alt,
                onPressed: onRefreshPreview,
              ),
              const SizedBox(width: 6),
              _ActionIconButton(
                icon: Icons.open_in_new,
                onPressed: onOpenInNewTab,
              ),
            ],
          );

          if (compact) {
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabRow,
                  ),
                ),
                const SizedBox(width: 6),
                actionsRow,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabRow,
                ),
              ),
              const SizedBox(width: 8),
              actionsRow,
            ],
          );
        },
      ),
    );
  }
}

class _PreviewInlineMeta extends StatelessWidget {
  final String url;

  const _PreviewInlineMeta({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Tooltip(
      message: url,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _previewHost(url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _previewHost(String url) {
  if (url.isEmpty) return 'Preview';
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return url;
  }
}

class ProjectChatModelSelector extends StatelessWidget {
  final List<ModelInfo> models;
  final String selectedModelId;
  final ValueChanged<String>? onChanged;
  final bool isLoading;
  final double minWidth;
  final double maxWidth;
  final double? width;
  final String placeholder;
  final String tooltip;

  const ProjectChatModelSelector({
    super.key,
    this.models = const <ModelInfo>[],
    this.selectedModelId = '',
    this.onChanged,
    this.isLoading = false,
    this.minWidth = 120,
    this.maxWidth = 156,
    this.width,
    this.placeholder = 'Model',
    this.tooltip = 'Select model',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return SizedBox(
      width: width ?? maxWidth,
      child: CompactSelector(
        options: models
            .map(
              (m) => CompactSelectorOption(
                value: m.id,
                label: m.displayName,
                tagLabel: m.badgeLabel,
              ),
            )
            .toList(),
        value: selectedModelId.trim().isEmpty ? null : selectedModelId.trim(),
        placeholder: placeholder,
        tooltip: tooltip,
        leadingIcon: Icons.auto_awesome_rounded,
        minWidth: minWidth,
        maxWidth: maxWidth,
        borderRadius: 13,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: isDark
            ? Color.alphaBlend(
                cs.primary.withValues(alpha: 0.12),
                cs.surfaceContainerHigh,
              )
            : Color.alphaBlend(
                cs.primary.withValues(alpha: 0.06),
                Colors.white,
              ),
        borderColor: isDark
            ? cs.primary.withValues(alpha: 0.28)
            : cs.outlineVariant.withValues(alpha: 0.9),
        menuBackgroundColor: isDark
            ? Color.alphaBlend(
                cs.surfaceContainerHighest.withValues(alpha: 0.96),
                cs.surface,
              )
            : Color.alphaBlend(
                Colors.white.withValues(alpha: 0.96),
                cs.surface,
              ),
        menuBorderColor: isDark
            ? cs.primary.withValues(alpha: 0.22)
            : cs.outlineVariant.withValues(alpha: 0.7),
        menuBorderRadius: 18,
        menuPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        itemHeight: 30,
        textColor: isDark ? cs.onSurface : cs.onSurface.withValues(alpha: 0.92),
        iconColor: isDark
            ? cs.primary.withValues(alpha: 0.9)
            : cs.onSurfaceVariant,
        trailingIcon: Icons.expand_more_rounded,
        isLoading: isLoading,
        onChanged: (isLoading || onChanged == null || models.isEmpty)
            ? null
            : (v) => onChanged!(v),
      ),
    );
  }
}

class ProjectChatEngineModeSegment extends StatelessWidget {
  final ChatEngineMode value;
  final String fastTooltip;
  final String thinkHardTooltip;
  final ValueChanged<ChatEngineMode>? onChanged;

  const ProjectChatEngineModeSegment({
    super.key,
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
                      isFast
                          ? Icons.flash_on_rounded
                          : Icons.psychology_rounded,
                      size: 11,
                      color: isFast ? Colors.green.shade900 : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isFast
                        ? Icons.psychology_alt_rounded
                        : Icons.flash_on_rounded,
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
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: hasLabel
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            if (hasLabel) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
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
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child:
                iconWidget ??
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
