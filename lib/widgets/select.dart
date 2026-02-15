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
    _hideDropdown();

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        child: _buildDropdown(),
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
    final effectiveBackgroundColor =
        widget.backgroundColor ?? theme.colorScheme.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: widget.padding,
      child: Material(
        elevation: widget.elevation.toDouble(),
        color: effectiveBackgroundColor,
        surfaceTintColor: widget.surfaceTintColor,
        borderRadius: BorderRadius.circular(8.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.menuMaxHeight ?? 300.0),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            children: widget.items.map((item) {
              if (item.isDisabled) {
                return item;
              }

              final isSelected = _selectedValue == item.value;

              return Material(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
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
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: item),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            size: widget.iconSize ?? 16,
                            color: theme.colorScheme.primary,
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
    final effectivePadding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final selectedItem = widget.items.firstWhere(
      (item) => item.value == _selectedValue,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (widget.items.isNotEmpty) {
            _showDropdown();
          }
        },
        child: Container(
          key: _containerKey,
          padding: effectivePadding,
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.errorText != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            mainAxisSize: widget.isExpanded
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Expanded(
                child: _selectedValue != null
                    ? selectedItem
                    : widget.hint ??
                          Text(
                            'Select an option',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
              ),
              Icon(
                widget.icon ?? Icons.keyboard_arrow_down,
                size: widget.iconSize ?? 20,
                color:
                    widget.iconEnabledColor ??
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
