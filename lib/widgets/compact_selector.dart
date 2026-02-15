import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canOpen = onChanged != null && options.isNotEmpty;
    final label = _selectedLabel();
    final tip = tooltip ?? label;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Tooltip(
        message: tip,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: PopupMenuButton<String>(
            enabled: canOpen,
            position: PopupMenuPosition.under,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 460),
            onSelected: canOpen ? onChanged : null,
            itemBuilder: (context) => options.map((option) {
              final selected = option.value == value;
              return PopupMenuItem<String>(
                value: option.value,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check, size: 16, color: cs.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 15, color: cs.onSurfaceVariant),
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
                        color: canOpen
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isLoading)
                    _BreathingDot(color: cs.primary)
                  else
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(
                        alpha: canOpen ? 1.0 : 0.55,
                      ),
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
