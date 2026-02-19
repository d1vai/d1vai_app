import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthTextInput extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

  const AuthTextInput({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.autofillHints,
  });

  @override
  State<AuthTextInput> createState() => _AuthTextInputState();
}

class _AuthTextInputState extends State<AuthTextInput> {
  late final FocusNode _focusNode;
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _isObscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AuthTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText && !widget.obscureText) {
      _isObscured = false;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isFocused = _focusNode.hasFocus;

    final borderColor = isFocused
        ? cs.primary.withValues(alpha: isDark ? 0.95 : 0.75)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.72 : 0.9);
    final fillColor = isDark
        ? cs.surfaceContainerHigh.withValues(alpha: 0.55)
        : cs.surface.withValues(alpha: 0.98);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isFocused ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? cs.primary.withValues(alpha: isDark ? 0.24 : 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: isFocused ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText ? _isObscured : false,
        validator: widget.validator,
        autofillHints: widget.autofillHints,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: widget.labelText,
          hintText: widget.hintText,
          labelStyle: TextStyle(color: cs.onSurfaceVariant),
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.82),
          ),
          contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 56),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon, size: 17, color: cs.primary),
              ),
            ),
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  tooltip: _isObscured ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: cs.onSurfaceVariant,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class AuthOtpInput extends StatefulWidget {
  final int count;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autoFocus;
  final bool autoSubmit;

  const AuthOtpInput({
    super.key,
    this.count = 6,
    required this.onCompleted,
    this.onChanged,
    this.autoFocus = true,
    this.autoSubmit = true,
  });

  @override
  State<AuthOtpInput> createState() => _AuthOtpInputState();
}

class _AuthOtpInputState extends State<AuthOtpInput> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final List<String> _otpValues = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.count; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode()..addListener(_onFocusChanged));
      _otpValues.add('');
      _controllers[i].addListener(() => _onTextChanged(i));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node
        ..removeListener(_onFocusChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onTextChanged(int index) {
    final currentValue = _controllers[index].text;

    if (currentValue.length > 1) {
      _handlePaste(currentValue, index);
      return;
    }

    setState(() {
      _otpValues[index] = currentValue;
    });

    final otpCode = _otpValues.join('');
    widget.onChanged?.call(otpCode);

    if (currentValue.isNotEmpty && index < widget.count - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    if (currentValue.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      _controllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index - 1].text.length,
      );
    }

    if (otpCode.length == widget.count && widget.autoSubmit) {
      widget.onCompleted(otpCode);
    }
  }

  void _handlePaste(String value, int index) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    var startIndex = index;
    var digitIndex = 0;
    while (digitIndex < digits.length && startIndex < widget.count) {
      _otpValues[startIndex] = digits[digitIndex];
      _controllers[startIndex].text = digits[digitIndex];
      digitIndex++;
      startIndex++;
    }
    setState(() {});

    final otpCode = _otpValues.join('');
    widget.onChanged?.call(otpCode);

    if (startIndex < widget.count) {
      FocusScope.of(context).requestFocus(_focusNodes[startIndex]);
      return;
    }
    FocusScope.of(context).unfocus();
    if (widget.autoSubmit) {
      widget.onCompleted(otpCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 340 ? 6.0 : 10.0;
        final computed =
            (constraints.maxWidth - spacing * (widget.count - 1)) /
            widget.count;
        final cellWidth = computed < 34
            ? 34.0
            : (computed > 54 ? 54.0 : computed);
        final cellHeight = cellWidth > 46 ? 60.0 : 54.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.count, (index) {
            final isFocused = _focusNodes[index].hasFocus;
            final hasValue = _otpValues[index].isNotEmpty;
            final borderColor = isFocused
                ? cs.primary
                : hasValue
                ? cs.primary.withValues(alpha: 0.56)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.74 : 0.9);
            final fillColor = isDark
                ? cs.surfaceContainerHigh.withValues(alpha: 0.55)
                : cs.surface.withValues(alpha: 0.98);

            return Padding(
              padding: EdgeInsets.only(
                right: index == widget.count - 1 ? 0 : spacing,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: cellWidth,
                height: cellHeight,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: isFocused ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isFocused
                          ? cs.primary.withValues(alpha: isDark ? 0.24 : 0.12)
                          : Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
                      blurRadius: isFocused ? 14 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  autofocus: widget.autoFocus && index == 0,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: widget.count,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onFieldSubmitted: (value) {
                    if (index < widget.count - 1 && value.isNotEmpty) {
                      FocusScope.of(
                        context,
                      ).requestFocus(_focusNodes[index + 1]);
                      return;
                    }
                    if (index == widget.count - 1 && value.isNotEmpty) {
                      final otpCode = _otpValues.join('');
                      if (otpCode.length == widget.count && widget.autoSubmit) {
                        widget.onCompleted(otpCode);
                      }
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
