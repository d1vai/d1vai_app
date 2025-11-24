import 'package:flutter/material.dart';

enum InputVariant {
  outlined,
  filled,
  underlined,
}

enum InputSize {
  small,
  medium,
  large,
}

/// Input Widget - A flexible text input component
class Input extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool disabled;
  final bool obscureText;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final InputVariant variant;
  final InputSize size;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final Color? fillColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final bool autoFocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;
  final bool showCursor;
  final bool dense;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final InputBorder? enabledBorder;
  final InputBorder? disabledBorder;
  final InputBorder? errorBorder;

  const Input({
    super.key,
    this.value,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.disabled = false,
    this.obscureText = false,
    this.hintText,
    this.labelText,
    this.helperText,
    this.errorText,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.variant = InputVariant.outlined,
    this.size = InputSize.medium,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.borderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.borderRadius,
    this.contentPadding,
    this.margin,
    this.autoFocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.showCursor = true,
    this.dense = false,
    this.border,
    this.focusedBorder,
    this.enabledBorder,
    this.disabledBorder,
    this.errorBorder,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = textStyle ??
        _getTextStyle(size, Theme.of(context).textTheme.bodyMedium);
    final effectiveLabelStyle = labelStyle ??
        _getTextStyle(size, Theme.of(context).textTheme.bodyMedium);
    final effectiveHintStyle = hintStyle ??
        _getTextStyle(size, Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ));
    final effectiveErrorStyle = errorStyle ??
        _getTextStyle(size, Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ));
    final effectiveContentPadding = contentPadding ?? _getPadding(size);
    final effectiveBorderRadius = borderRadius ?? _getBorderRadius(size);
    final effectiveFillColor = _getFillColor(fillColor, disabled, context);
    final effectiveBorderColor = _getBorderColor(borderColor, disabled, context);
    final effectiveFocusedBorderColor =
        focusedBorderColor ?? Theme.of(context).colorScheme.primary;
    final effectiveErrorBorderColor =
        errorBorderColor ?? Theme.of(context).colorScheme.error;

    final effectiveBorder = border ??
        _buildBorder(
          variant,
          effectiveBorderRadius,
          effectiveBorderColor,
          disabled,
        );
    final effectiveFocusedBorder = focusedBorder ??
        _buildBorder(
          variant,
          effectiveBorderRadius,
          effectiveFocusedBorderColor,
          disabled,
        );
    final effectiveEnabledBorder = enabledBorder ??
        _buildBorder(
          variant,
          effectiveBorderRadius,
          effectiveBorderColor,
          disabled,
        );
    final effectiveDisabledBorder = disabledBorder ??
        _buildBorder(
          variant,
          effectiveBorderRadius,
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          disabled,
        );
    final effectiveErrorBorder = errorBorder ??
        _buildBorder(
          variant,
          effectiveBorderRadius,
          effectiveErrorBorderColor,
          disabled,
        );

    return Container(
      margin: margin,
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly || disabled,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        textAlign: textAlign,
        textAlignVertical: textAlignVertical,
        style: effectiveTextStyle,
        autofocus: autoFocus,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        enabled: enabled && !disabled,
        showCursor: showCursor,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          helperText: helperText,
          errorText: errorText,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefix: prefix,
          suffix: suffix,
          filled: variant != InputVariant.underlined,
          fillColor: effectiveFillColor,
          isDense: dense,
          contentPadding: effectiveContentPadding,
          border: effectiveBorder,
          focusedBorder: effectiveFocusedBorder,
          enabledBorder: effectiveEnabledBorder,
          disabledBorder: effectiveDisabledBorder,
          errorBorder: effectiveErrorBorder,
          hintStyle: effectiveHintStyle,
          labelStyle: effectiveLabelStyle,
          errorStyle: effectiveErrorStyle,
          hoverColor: hoverColor ?? Colors.transparent,
          focusColor: focusColor ?? Colors.transparent,
        ),
      ),
    );
  }

  InputBorder _buildBorder(
    InputVariant variant,
    double borderRadius,
    Color borderColor,
    bool disabled,
  ) {
    switch (variant) {
      case InputVariant.outlined:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: borderColor,
            width: disabled ? 0.5 : 1.0,
          ),
        );
      case InputVariant.filled:
        return UnderlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            topRight: Radius.circular(borderRadius),
          ),
          borderSide: BorderSide(
            color: borderColor,
            width: disabled ? 0.5 : 1.0,
          ),
        );
      case InputVariant.underlined:
        return UnderlineInputBorder(
          borderSide: BorderSide(
            color: borderColor,
            width: disabled ? 0.5 : 1.0,
          ),
        );
    }
  }

  TextStyle _getTextStyle(InputSize size, TextStyle? baseStyle) {
    if (baseStyle == null) return const TextStyle();

    switch (size) {
      case InputSize.small:
        return baseStyle.copyWith(fontSize: 12);
      case InputSize.medium:
        return baseStyle.copyWith(fontSize: 14);
      case InputSize.large:
        return baseStyle.copyWith(fontSize: 16);
    }
  }

  EdgeInsetsGeometry _getPadding(InputSize size) {
    switch (size) {
      case InputSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case InputSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case InputSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  double _getBorderRadius(InputSize size) {
    switch (size) {
      case InputSize.small:
        return 6.0;
      case InputSize.medium:
        return 8.0;
      case InputSize.large:
        return 10.0;
    }
  }

  Color _getFillColor(Color? fillColor, bool disabled, BuildContext context) {
    if (disabled) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04);
    }
    return fillColor ??
        (variant == InputVariant.filled
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : Colors.transparent);
  }

  Color _getBorderColor(Color? borderColor, bool disabled, BuildContext context) {
    if (disabled) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    }
    return borderColor ?? Theme.of(context).colorScheme.outline;
  }
}

/// OutlinedInput - Outlined variant of Input
class OutlinedInput extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final InputSize size;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;

  const OutlinedInput({
    super.key,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.size = InputSize.medium,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.contentPadding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      value: value,
      onChanged: onChanged,
      hintText: hintText,
      labelText: labelText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      variant: InputVariant.outlined,
      size: size,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      contentPadding: contentPadding,
      textStyle: textStyle,
    );
  }
}

/// FilledInput - Filled variant of Input
class FilledInput extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final InputSize size;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;

  const FilledInput({
    super.key,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.size = InputSize.medium,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.contentPadding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      value: value,
      onChanged: onChanged,
      hintText: hintText,
      labelText: labelText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      variant: InputVariant.filled,
      size: size,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      contentPadding: contentPadding,
      textStyle: textStyle,
    );
  }
}

/// SearchInput - Specialized input for search
class SearchInput extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final InputSize size;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;

  const SearchInput({
    super.key,
    this.value,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search...',
    this.size = InputSize.medium,
    this.contentPadding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: 16,
          vertical: size == InputSize.small
              ? 8
              : size == InputSize.medium
                  ? 12
                  : 16,
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          contentPadding: effectivePadding,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              size == InputSize.small
                  ? 6
                  : size == InputSize.medium
                      ? 8
                      : 10,
            ),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              size == InputSize.small
                  ? 6
                  : size == InputSize.medium
                      ? 8
                      : 10,
            ),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              size == InputSize.small
                  ? 6
                  : size == InputSize.medium
                      ? 8
                      : 10,
            ),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2.0,
            ),
          ),
        ),
        style: textStyle ??
            theme.textTheme.bodyMedium?.copyWith(
              fontSize: size == InputSize.small
                  ? 12
                  : size == InputSize.medium
                      ? 14
                      : 16,
            ),
      ),
    );
  }
}
