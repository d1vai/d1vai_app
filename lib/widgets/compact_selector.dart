import 'package:flutter/material.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';

class CompactSelectorOption {
  final String value;
  final String label;

  const CompactSelectorOption({required this.value, required this.label});
}

class CompactSelector extends StatelessWidget {
  final List<CompactSelectorOption> options;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool isLoading;
  final String placeholder;
  final String? displayLabel;
  final String? tooltip;
  final IconData? leadingIcon;
  final double minWidth;
  final double maxWidth;
  final TextAlign textAlign;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;
  final IconData trailingIcon;
  final Color? menuBackgroundColor;
  final Color? menuBorderColor;
  final double menuBorderRadius;
  final EdgeInsetsGeometry menuPadding;
  final double itemHeight;
  final bool emphasizeSelectedOption;

  const CompactSelector({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.isLoading = false,
    this.placeholder = 'Select',
    this.displayLabel,
    this.tooltip,
    this.leadingIcon,
    this.minWidth = 110,
    this.maxWidth = 160,
    this.textAlign = TextAlign.right,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.iconColor,
    this.trailingIcon = Icons.unfold_more_rounded,
    this.menuBackgroundColor,
    this.menuBorderColor,
    this.menuBorderRadius = 16,
    this.menuPadding = const EdgeInsets.symmetric(vertical: 8),
    this.itemHeight = 44,
    this.emphasizeSelectedOption = true,
  });

  String _selectedLabel() {
    if (displayLabel != null && displayLabel!.trim().isNotEmpty) {
      return displayLabel!.trim();
    }
    final current = value?.trim();
    if (current == null || current.isEmpty) return placeholder;
    for (final option in options) {
      if (option.value == current) return option.label;
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canOpen = onChanged != null && options.isNotEmpty;
    final label = _selectedLabel();
    final tip = tooltip ?? label;
    final resolvedBackgroundColor =
        backgroundColor ?? cs.surfaceContainerHighest.withValues(alpha: 0.42);
    final resolvedBorderColor =
        borderColor ?? cs.outlineVariant.withValues(alpha: 0.8);
    final resolvedTextColor =
        textColor ??
        (canOpen ? cs.onSurface : cs.onSurface.withValues(alpha: 0.62));
    final resolvedIconColor =
        iconColor ??
        cs.onSurfaceVariant.withValues(alpha: canOpen ? 1.0 : 0.55);
    final resolvedMenuBackgroundColor =
        menuBackgroundColor ??
        Color.alphaBlend(
          cs.surfaceContainerHigh.withValues(alpha: 0.94),
          cs.surface,
        );
    final resolvedMenuBorderColor =
        menuBorderColor ?? cs.outlineVariant.withValues(alpha: 0.7);

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Tooltip(
        message: tip,
        child: Container(
          decoration: BoxDecoration(
            color: resolvedBackgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: resolvedBorderColor),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.18 : 0.06,
                ),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: PopupMenuButton<String>(
            enabled: canOpen,
            position: PopupMenuPosition.under,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 460),
            color: resolvedMenuBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shadowColor: cs.shadow.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(menuBorderRadius),
              side: BorderSide(color: resolvedMenuBorderColor),
            ),
            menuPadding: menuPadding,
            onSelected: canOpen ? onChanged : null,
            itemBuilder: (context) => options.map((option) {
              final selected = option.value == value;
              return PopupMenuItem<String>(
                value: option.value,
                height: itemHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected && emphasizeSelectedOption
                        ? cs.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: selected && emphasizeSelectedOption
                        ? Border.all(color: cs.primary.withValues(alpha: 0.18))
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.88,
                                ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? cs.primary.withValues(alpha: 0.9)
                                : cs.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.auto_awesome_rounded,
                          size: 11,
                          color: selected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant.withValues(alpha: 0.74),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: textAlign,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      if (selected && emphasizeSelectedOption) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            loc?.translate('compact_selector_active') ?? 'ON',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 15, color: resolvedIconColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: textAlign,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: resolvedTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isLoading)
                    _BreathingDot(color: cs.primary)
                  else
                    Icon(trailingIcon, size: 16, color: resolvedIconColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingDot extends StatefulWidget {
  final Color color;

  const _BreathingDot({required this.color});

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1.0 + (0.25 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.65 + (0.35 * t)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.18 + (0.24 * t)),
                  blurRadius: 6,
                  spreadRadius: 0.6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
