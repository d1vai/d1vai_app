import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthTextInput extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData? icon;
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
    this.icon,
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
    final isFocused = _focusNode.hasFocus;

    final borderColor = isFocused
        ? cs.primary
        : cs.outlineVariant.withValues(alpha: 0.9);
    final fillColor = cs.surfaceContainerLowest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isFocused ? 1.5 : 1),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText ? _isObscured : false,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(
                      widget.icon,
                      size: 18,
                      color: isFocused ? cs.primary : cs.onSurfaceVariant,
                    ),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      tooltip: _isObscured ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setState(() => _isObscured = !_isObscured),
                      icon: Icon(
                        _isObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    )
                  : null,
              errorStyle: theme.textTheme.bodySmall?.copyWith(
                color: cs.error,
                height: 1.25,
              ),
            ),
          ),
        ),
      ],
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
  bool _isAutoAdvancing = false;

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
    if (_isAutoAdvancing) return;
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
      _isAutoAdvancing = true;
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isAutoAdvancing = false;
      });
    }

    if (currentValue.isEmpty && index > 0) {
      _isAutoAdvancing = true;
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      _controllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index - 1].text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isAutoAdvancing = false;
      });
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
        final cellHeight = cellWidth > 46 ? 52.0 : 48.0;

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
            final fillColor = cs.surfaceContainerLowest;

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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isFocused ? 1.5 : 1,
                  ),
                ),
                child: TextFormField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  autofocus: widget.autoFocus && index == 0,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
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
