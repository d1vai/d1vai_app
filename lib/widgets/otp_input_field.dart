import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OTP 输入字段组件 - 支持 6 位数字验证码输入
class OtpInputField extends StatefulWidget {
  /// 输入框数量（默认为 6）
  final int count;

  /// 输入完成回调
  final Function(String) onCompleted;

  /// 输入改变回调
  final Function(String)? onChanged;

  /// 输入框宽度
  final double width;

  /// 输入框高度
  final double height;

  /// 输入框间距
  final double spacing;

  /// 是否自动聚焦第一个输入框
  final bool autoFocus;

  const OtpInputField({
    super.key,
    this.count = 6,
    required this.onCompleted,
    this.onChanged,
    this.width = 50.0,
    this.height = 60.0,
    this.spacing = 8.0,
    this.autoFocus = true,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<String> _values;
  late List<GlobalKey> _fieldKeys;

  @override
  void initState() {
    super.initState();
    _values = List<String>.filled(widget.count, '');
    _controllers = List<TextEditingController>.generate(
      widget.count,
      (index) => TextEditingController(),
    );
    _focusNodes = List<FocusNode>.generate(
      widget.count,
      (index) => FocusNode(),
    );
    _fieldKeys = List<GlobalKey>.generate(widget.count, (index) => GlobalKey());

    // 为每个控制器添加监听器
    for (int i = 0; i < widget.count; i++) {
      _controllers[i].addListener(() => _onTextChanged(i));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// 处理文本变化
  void _onTextChanged(int index) {
    final value = _controllers[index].text;
    setState(() {
      _values[index] = value;
    });

    // 通知变化
    if (widget.onChanged != null) {
      widget.onChanged!(_values.join());
    }

    // 自动跳转到下一个输入框
    if (value.isNotEmpty && index < widget.count - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    // 检查是否所有输入框都已填写
    if (_values.every((v) => v.isNotEmpty)) {
      final otpCode = _values.join();
      widget.onCompleted(otpCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (index) {
        return Container(
          key: _fieldKeys[index],
          width: widget.width,
          height: widget.height,
          margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            autofocus: widget.autoFocus && index == 0,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            onFieldSubmitted: (value) {
              // 按下回车键时的处理
              if (index < widget.count - 1) {
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              } else {
                // 最后一个输入框，完成输入
                if (_values.every((v) => v.isNotEmpty)) {
                  final otpCode = _values.join();
                  widget.onCompleted(otpCode);
                }
              }
            },
          ),
        );
      }),
    );
  }
}

/// 优化的 OTP 输入框 - 支持一次性输入、粘贴和流畅操作
class SimpleOtpInput extends StatefulWidget {
  final int count;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool autoFocus;

  const SimpleOtpInput({
    super.key,
    this.count = 6,
    required this.onCompleted,
    this.onChanged,
    this.autoFocus = true,
  });

  @override
  State<SimpleOtpInput> createState() => _SimpleOtpInputState();
}

class _SimpleOtpInputState extends State<SimpleOtpInput> {
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

    // 如果有输入，自动跳转到下一个框
    if (currentValue.isNotEmpty && index < widget.count - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    // 如果是删除操作且当前框为空，自动跳转到前一个框
    if (currentValue.isEmpty && index > 0) {
      // 检查是否是删除操作（检查前一个值不为空）
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      // 选中文本，方便用户继续删除或替换
      _controllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index - 1].text.length,
      );
    }

    // 检查是否完成输入
    if (otpCode.length == widget.count) {
      widget.onCompleted(otpCode);
    }
  }

  /// 处理粘贴操作
  void _handlePaste(String value, int index) {
    // 提取数字
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return;

    // 从粘贴位置开始填充
    int startIndex = index;
    int digitIndex = 0;

    // 填充当前框及后续框
    while (digitIndex < digits.length && startIndex < widget.count) {
      setState(() {
        _otpValues[startIndex] = digits[digitIndex];
        _controllers[startIndex].text = digits[digitIndex];
      });

      digitIndex++;
      startIndex++;
    }

    // 通知变化
    final otpCode = _otpValues.join('');
    if (widget.onChanged != null) {
      widget.onChanged!(otpCode);
    }

    // 跳转到下一个未填写的框
    int nextIndex = startIndex;
    if (nextIndex < widget.count) {
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
    } else {
      // 所有框都填写完成，关闭键盘
      FocusScope.of(context).unfocus();
    }

    // 检查是否完成输入
    if (otpCode.length == widget.count) {
      widget.onCompleted(otpCode);
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
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            // 添加长按粘贴支持
            onTap: () {
              // 如果框为空且不是第一个，尝试从左框移动光标
              if (_controllers[index].text.isEmpty && index > 0) {
                _controllers[index - 1].selection = TextSelection.collapsed(
                  offset: _controllers[index - 1].text.length,
                );
                FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
              }
            },
            onFieldSubmitted: (value) {
              if (index < widget.count - 1 && value.isNotEmpty) {
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              } else if (index == widget.count - 1 && value.isNotEmpty) {
                // 最后一个框，关闭键盘
                final otpCode = _otpValues.join('');
                if (otpCode.length == widget.count) {
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
