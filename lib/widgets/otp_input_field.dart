import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 优化的 OTP 输入框组件
/// 支持一次性输入、粘贴、流畅删除操作和自动提交
class OptimizedOtpInput extends StatefulWidget {
  final int count;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool autoFocus;
  final bool autoSubmit; // 新增：是否在输入完成后自动调用 onCompleted

  const OptimizedOtpInput({
    super.key,
    this.count = 6,
    required this.onCompleted,
    this.onChanged,
    this.autoFocus = true,
    this.autoSubmit = true, // 默认为 true，自动提交
  });

  @override
  State<OptimizedOtpInput> createState() => _OptimizedOtpInputState();
}

class _OptimizedOtpInputState extends State<OptimizedOtpInput> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final List<String> _otpValues = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.count; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
      _otpValues.add('');
      _controllers[i].addListener(() => _onTextChanged(i));
    }
  }

  void _onTextChanged(int index) {
    final currentValue = _controllers[index].text;

    // 检查是否是粘贴操作（输入超过1个字符）
    if (currentValue.length > 1) {
      _handlePaste(currentValue, index);
      return;
    }

    setState(() {
      _otpValues[index] = currentValue;
    });

    final otpCode = _otpValues.join('');
    if (widget.onChanged != null) {
      widget.onChanged!(otpCode);
    }

    // 自动跳转到下一个框
    if (currentValue.isNotEmpty && index < widget.count - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    // 如果是删除操作且当前框为空，自动跳转到前一个框
    if (currentValue.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      _controllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index - 1].text.length,
      );
    }

    // 检查是否完成输入
    final isCompleted = otpCode.length == widget.count;
    if (isCompleted && widget.autoSubmit) {
      widget.onCompleted(otpCode);
    }
  }

  /// 处理粘贴操作
  void _handlePaste(String value, int index) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return;

    int startIndex = index;
    int digitIndex = 0;

    while (digitIndex < digits.length && startIndex < widget.count) {
      setState(() {
        _otpValues[startIndex] = digits[digitIndex];
        _controllers[startIndex].text = digits[digitIndex];
      });
      digitIndex++;
      startIndex++;
    }

    final otpCode = _otpValues.join('');
    if (widget.onChanged != null) {
      widget.onChanged!(otpCode);
    }

    int nextIndex = startIndex;
    if (nextIndex < widget.count) {
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
    } else {
      FocusScope.of(context).unfocus();
      if (widget.autoSubmit) {
        widget.onCompleted(otpCode);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.count, (index) {
        return SizedBox(
          width: 45,
          height: 55,
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            autofocus: widget.autoFocus && index == 0,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6, // 允许粘贴时输入多个字符
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            onFieldSubmitted: (value) {
              if (index < widget.count - 1 && value.isNotEmpty) {
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              } else if (index == widget.count - 1 && value.isNotEmpty) {
                final otpCode = _otpValues.join('');
                if (otpCode.length == widget.count && widget.autoSubmit) {
                  widget.onCompleted(otpCode);
                }
                FocusScope.of(context).unfocus();
              }
            },
          ),
        );
      }),
    );
  }
}
