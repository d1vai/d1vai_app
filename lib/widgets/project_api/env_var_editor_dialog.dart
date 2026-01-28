import 'package:flutter/material.dart';

import '../../models/env_var.dart';

class EnvVarEditorResult {
  final String key;
  final String value;
  final String? description;
  final bool isSensitive;

  const EnvVarEditorResult({
    required this.key,
    required this.value,
    required this.description,
    required this.isSensitive,
  });
}

class EnvVarEditorDialog extends StatefulWidget {
  final EnvVar? initial;
  final bool allowEditKey;

  const EnvVarEditorDialog({
    super.key,
    this.initial,
    this.allowEditKey = true,
  });

  @override
  State<EnvVarEditorDialog> createState() => _EnvVarEditorDialogState();
}

class _EnvVarEditorDialogState extends State<EnvVarEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  late final TextEditingController _descController;
  bool _isSensitive = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _keyController = TextEditingController(text: initial?.key ?? '');
    _valueController = TextEditingController(text: initial?.value ?? '');
    _descController = TextEditingController(text: initial?.description ?? '');
    _isSensitive = initial?.isSensitive ?? true;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _validKey {
    final k = _keyController.text.trim();
    if (k.isEmpty) return false;
    // Backend allows alnum/_/-, and uppercases; keep same constraints client-side.
    final ok = RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(k);
    return ok;
  }

  bool get _validValue => _valueController.text.trim().isNotEmpty;

  void _submit() {
    final key = _keyController.text.trim();
    final value = _valueController.text;
    final desc = _descController.text.trim();

    Navigator.of(context).pop(
      EnvVarEditorResult(
        key: key,
        value: value,
        description: desc.isEmpty ? null : desc,
        isSensitive: _isSensitive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initial != null;
    final canSubmit = _validKey && _validValue;

    return AlertDialog(
      title: Text(isEdit ? 'Edit variable' : 'Add variable'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              enabled: widget.allowEditKey,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Key',
                hintText: 'EXAMPLE_API_KEY',
                errorText:
                    _keyController.text.trim().isEmpty || _validKey
                        ? null
                        : 'Use only letters, numbers, _ and -',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'Paste the secret value…',
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _isSensitive,
              onChanged: (v) => setState(() => _isSensitive = v),
              title: const Text('Sensitive'),
              subtitle: Text(
                _isSensitive
                    ? 'Masked in lists by default'
                    : 'Visible in lists',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

