import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import 'code_tab_editor.dart';

class CodeTabEditingPane extends StatelessWidget {
  final CodeController controller;
  final String originalText;
  final String languageLabel;
  final bool wrapEnabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onToggleWrap;
  final bool compact;
  final Widget? header;

  const CodeTabEditingPane({
    super.key,
    required this.controller,
    required this.originalText,
    required this.languageLabel,
    required this.wrapEnabled,
    required this.onChanged,
    required this.onCancel,
    required this.onToggleWrap,
    required this.compact,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (header != null) header!,
        Expanded(
          child: CodeTabEditor(
            controller: controller,
            originalText: originalText,
            languageLabel: languageLabel,
            wrapEnabled: wrapEnabled,
            onChanged: onChanged,
            onCancel: onCancel,
            onToggleWrap: onToggleWrap,
            compact: compact,
          ),
        ),
      ],
    );
  }
}
