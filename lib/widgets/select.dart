import 'package:flutter/material.dart';

/// Select Widget - A dropdown selection component
class Select<T> extends StatefulWidget {
  final T? value;
  final ValueChanged<T?>? onChanged;
  final List<SelectItem<T>> items;
  final Widget? hint;
  final Widget? disabledHint;
  final int elevation;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final EdgeInsetsGeometry? padding;
  final double? menuMaxHeight;
  final bool? showSelectedItems;
  final Offset? offset;
  final IconData? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double? iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? hintTextMaxLines;
  final String? label;
  final TextStyle? labelStyle;
  final String? errorText;
  final TextStyle? errorStyle;

  const Select({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.disabledHint,
    this.elevation = 8,
    this.backgroundColor,
    this.surfaceTintColor,
    this.padding,
    this.menuMaxHeight,
    this.showSelectedItems,
    this.offset,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize,
    this.isDense = false,
    this.isExpanded = false,
    this.hintTextMaxLines,
    this.label,
    this.labelStyle,
    this.errorText,
    this.errorStyle,
  });

  @override
  State<Select<T>> createState() => _SelectState<T>();
}

class _SelectState<T> extends State<Select<T>> {
  T? _selectedValue;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _containerKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool get _canOpen => widget.onChanged != null && widget.items.isNotEmpty;

  SelectItem<T>? get _selectedItemOrNull {
    for (final item in widget.items) {
      if (item.value == _selectedValue) return item;
    }
    return null;
  }

  double _triggerWidth() {
    final context = _containerKey.currentContext;
    if (context == null) return 240;
    final box = context.findRenderObject();
    if (box is RenderBox) return box.size.width;
    return 240;
  }

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(Select<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
  }

  void _showDropdown() {
    if (!_canOpen) return;
    _hideDropdown();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideDropdown,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: widget.offset ?? const Offset(0, 8),
            child: _buildDropdown(),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBackgroundColor =
        widget.backgroundColor ??
        Color.alphaBlend(
          colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
          colorScheme.surface,
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _triggerWidth(),
      child: Material(
        elevation: widget.elevation.toDouble(),
        color: effectiveBackgroundColor,
        surfaceTintColor: widget.surfaceTintColor,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.menuMaxHeight ?? 300.0),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            children: widget.items.map((item) {
              if (item.isDisabled) {
                return Opacity(
                  opacity: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    child: item,
                  ),
                );
              }

              final isSelected = _selectedValue == item.value;

              return Material(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedValue = item.value;
                    });
                    widget.onChanged?.call(item.value);
                    _hideDropdown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 11.0,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: item),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.9)
                                  : colorScheme.outlineVariant.withValues(
                                      alpha: 0.72,
                                    ),
                            ),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: widget.iconSize ?? 12,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.68,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideDropdown();
    super.dispose();
  }

  Widget _buildTrigger() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectivePadding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final selectedItem = _selectedItemOrNull;
    final hasValue = _selectedValue != null && selectedItem != null;
    final disabled = !_canOpen;
    final backgroundColor = disabled
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.38)
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.52,
          );
    final borderColor = widget.errorText != null
        ? colorScheme.error
        : (disabled
              ? colorScheme.outlineVariant.withValues(alpha: 0.42)
              : colorScheme.outlineVariant.withValues(alpha: 0.72));

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _canOpen ? _showDropdown : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          key: _containerKey,
          padding: effectivePadding,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.0),
            borderRadius: BorderRadius.circular(14.0),
            color: backgroundColor,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.10
                            : 0.04,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: widget.isExpanded
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Flexible(
                fit: widget.isExpanded ? FlexFit.tight : FlexFit.loose,
                child: hasValue
                    ? DefaultTextStyle.merge(
                        style:
                            theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ) ??
                            TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                        child: selectedItem,
                      )
                    : widget.hint ??
                          Text(
                            'Select an option',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
              ),
              const SizedBox(width: 10),
              AnimatedRotation(
                turns: _overlayEntry != null ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  widget.icon ?? Icons.keyboard_arrow_down_rounded,
                  size: widget.iconSize ?? 20,
                  color:
                      (disabled
                          ? widget.iconDisabledColor
                          : widget.iconEnabledColor) ??
                      colorScheme.onSurfaceVariant.withValues(
                        alpha: disabled ? 0.52 : 0.82,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.label!,
              style:
                  widget.labelStyle ??
                  theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        _buildTrigger(),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              widget.errorText!,
              style:
                  widget.errorStyle ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
            ),
          ),
      ],
    );
  }
}

/// SelectItem - An item in the select dropdown
class SelectItem<T> extends StatelessWidget {
  final T value;
  final Widget child;
  final bool isDisabled;
  final VoidCallback? onTap;

  const SelectItem({
    super.key,
    required this.value,
    required this.child,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return isDisabled ? Opacity(opacity: 0.5, child: child) : child;
  }
}

/// SimpleSelect - A simple select component with string items
class SimpleSelect<T> extends StatelessWidget {
  final T? value;
  final ValueChanged<T?>? onChanged;
  final List<T> items;
  final String Function(T)? itemLabel;
  final Widget Function(T)? itemBuilder;
  final Widget? hint;
  final String? label;
  final bool isExpanded;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final double? menuMaxHeight;

  const SimpleSelect({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.itemLabel,
    this.itemBuilder,
    this.hint,
    this.label,
    this.isExpanded = false,
    this.backgroundColor,
    this.padding,
    this.menuMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final selectItems = items.map((item) {
      final label = itemLabel != null ? itemLabel!(item) : item.toString();

      final builder = itemBuilder != null
          ? itemBuilder!(item)
          : Text(label, style: Theme.of(context).textTheme.bodyMedium);

      return SelectItem(value: item, child: builder);
    }).toList();

    return Select(
      items: selectItems,
      value: value,
      onChanged: onChanged,
      hint: hint,
      label: label,
      isExpanded: isExpanded,
      backgroundColor: backgroundColor,
      padding: padding,
      menuMaxHeight: menuMaxHeight,
    );
  }
}

/// DropdownSelect - A dropdown button select component
class DropdownSelect<T> extends StatelessWidget {
  final T? value;
  final ValueChanged<T?>? onChanged;
  final List<DropdownMenuItem<T>> items;
  final Widget? hint;
  final Widget? disabledHint;
  final IconData? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double? iconSize;
  final bool isDense;
  final bool isExpanded;
  final double elevation;
  final Color? dropdownColor;
  final EdgeInsetsGeometry? padding;
  final double? menuMaxHeight;
  final String? label;
  final TextStyle? labelStyle;
  final String? errorText;
  final TextStyle? errorStyle;

  const DropdownSelect({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.disabledHint,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize,
    this.isDense = false,
    this.isExpanded = false,
    this.elevation = 8,
    this.dropdownColor,
    this.padding,
    this.menuMaxHeight,
    this.label,
    this.labelStyle,
    this.errorText,
    this.errorStyle,
  });

  @override
  Widget build(BuildContext context) {
    final selectItems = items.where((item) => item.value != null).map((item) {
      return SelectItem(value: item.value as T, child: item.child);
    }).toList();

    return Select(
      items: selectItems,
      value: value,
      onChanged: onChanged,
      hint: hint,
      disabledHint: disabledHint,
      elevation: elevation.round(),
      backgroundColor: dropdownColor,
      padding: padding,
      menuMaxHeight: menuMaxHeight,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      isDense: isDense,
      isExpanded: isExpanded,
      label: label,
      labelStyle: labelStyle,
      errorText: errorText,
      errorStyle: errorStyle,
    );
  }
}
