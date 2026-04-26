import 'package:flutter/material.dart';

import '../adaptive_modal.dart';
import '../../l10n/app_localizations.dart';
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

  const EnvVarEditorDialog({super.key, this.initial, this.allowEditKey = true});

  @override
  State<EnvVarEditorDialog> createState() => _EnvVarEditorDialogState();
}

class _EnvVarEditorDialogState extends State<EnvVarEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  late final TextEditingController _descController;
  bool _isSensitive = true;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

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

    return AdaptiveModalContainer(
      maxWidth: 520,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdaptiveModalHeader(
                title: isEdit
                    ? _t('project_api_edit_variable', 'Edit variable')
                    : _t('project_api_add_variable', 'Add variable'),
                subtitle: _t(
                  'project_api_value_hint',
                  'Add a clear key and keep sensitive values masked by default.',
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              TextField(
                controller: _keyController,
                enabled: widget.allowEditKey,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: _t('project_api_key', 'Key'),
                  hintText: _t('project_api_key_example', 'EXAMPLE_API_KEY'),
                  errorText: _keyController.text.trim().isEmpty || _validKey
                      ? null
                      : _t(
                          'project_api_key_error',
                          'Use only letters, numbers, _ and -',
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: _t('project_api_value', 'Value'),
                  hintText: _t(
                    'project_api_value_hint',
                    'Paste the secret value...',
                  ),
                ),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: _t(
                    'project_api_description_optional',
                    'Description (optional)',
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _isSensitive,
                onChanged: (v) => setState(() => _isSensitive = v),
                title: Text(_t('project_api_sensitive', 'Sensitive')),
                subtitle: Text(
                  _isSensitive
                      ? _t(
                          'project_api_sensitive_masked',
                          'Masked in lists by default',
                        )
                      : _t('project_api_sensitive_visible', 'Visible in lists'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_t('cancel', 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
                      child: Text(
                        isEdit
                            ? _t('save', 'Save')
                            : _t('project_api_add', 'Add'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
