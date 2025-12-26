import 'package:flutter/material.dart';

/// 可复用的搜索组件
/// 支持在 AppBar 中作为 title 使用，也可以独立使用
class SearchField extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final String? initialValue;
  final double? width;
  final EdgeInsets? margin;
  final double height;
  final BorderRadius? borderRadius;

  const SearchField({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.initialValue,
    this.width,
    this.margin,
    this.height = 40,
    this.borderRadius,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showClear = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _showClear = widget.initialValue?.isNotEmpty ?? false;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final next = _focusNode.hasFocus;
    if (next != _isFocused) {
      setState(() {
        _isFocused = next;
      });
    }
  }

  void _onTextChanged() {
    final showClear = _controller.text.isNotEmpty;
    if (showClear != _showClear) {
      setState(() {
        _showClear = showClear;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    setState(() {
      _showClear = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);
    final borderColor = _isFocused
        ? colorScheme.primary.withValues(alpha: 0.55)
        : colorScheme.outlineVariant.withValues(alpha: 0.75);
    final fillColor = colorScheme.surfaceContainerHighest;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: widget.width ?? double.infinity,
      margin: widget.margin ?? EdgeInsets.zero,
      height: widget.height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            suffixIcon: SizedBox(
              width: 40,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showClear ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !_showClear,
                    child: IconButton(
                      onPressed: _clear,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      tooltip: 'Clear',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            border: InputBorder.none,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// 在 AppBar 中使用的紧凑搜索组件
class AppBarSearchField extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppBarSearchField({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  State<AppBarSearchField> createState() => _AppBarSearchFieldState();
}

class _AppBarSearchFieldState extends State<AppBarSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showClear = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final next = _focusNode.hasFocus;
    if (next != _isFocused) {
      setState(() {
        _isFocused = next;
      });
    }
  }

  void _onTextChanged() {
    final showClear = _controller.text.isNotEmpty;
    if (showClear != _showClear) {
      setState(() {
        _showClear = showClear;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    setState(() {
      _showClear = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = _isFocused
        ? colorScheme.primary.withValues(alpha: 0.55)
        : colorScheme.outlineVariant.withValues(alpha: 0.70);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
          suffixIcon: SizedBox(
            width: 36,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showClear ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !_showClear,
                  child: IconButton(
                    onPressed: _clear,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    tooltip: 'Clear',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
        ),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
        ),
      ),
    );
  }
}
