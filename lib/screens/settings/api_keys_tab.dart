import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/login_required_view.dart';
import '../../widgets/snackbar_helper.dart';

class SettingsApiKeysTab extends StatefulWidget {
  const SettingsApiKeysTab({super.key});

  @override
  State<SettingsApiKeysTab> createState() => _SettingsApiKeysTabState();
}

class _SettingsApiKeysTabState extends State<SettingsApiKeysTab> {
  final D1vaiService _service = D1vaiService();

  bool _loading = true;
  bool _creating = false;
  bool _revoking = false;
  String? _latestSecret;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.getUserApiKeys();
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDate(dynamic value, AppLocalizations? loc) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return loc?.translate('api_keys_never') ?? 'Never';
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal().toString() ?? raw;
  }

  Future<void> _create({
    required String name,
    required String description,
    required AppLocalizations? loc,
  }) async {
    if (name.trim().isEmpty) return;
    setState(() {
      _creating = true;
    });
    try {
      final created = await _service.createUserApiKey(
        name: name.trim(),
        description: description.trim(),
      );
      if (!mounted) return;
      setState(() {
        _latestSecret = (created['api_key'] ?? '').toString();
      });
      await _load();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: loc?.translate('settings_api_key') ?? 'API Key',
        message:
            loc?.translate('api_keys_create_success') ??
            'API key created. Copy it now, it will not be shown again.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: loc?.translate('settings_api_key') ?? 'API Key',
        message:
            '${loc?.translate('api_keys_create_failed') ?? 'Failed to create API key'}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _revoke(int id) async {
    setState(() {
      _revoking = true;
    });
    try {
      await _service.revokeUserApiKey(id);
      await _load();
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      SnackBarHelper.showSuccess(
        context,
        title: loc?.translate('settings_api_key') ?? 'API Key',
        message: loc?.translate('api_keys_revoke_success') ?? 'API key revoked',
      );
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      SnackBarHelper.showError(
        context,
        title: loc?.translate('settings_api_key') ?? 'API Key',
        message:
            '${loc?.translate('api_keys_revoke_failed') ?? 'Failed to revoke API key'}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _revoking = false;
        });
      }
    }
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    AppLocalizations? loc,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateApiKeyDialog(
        loc: loc,
        creating: _creating,
        onCreate: ({required String name, required String description}) async {
          await _create(name: name, description: description, loc: loc);
        },
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    Map<String, dynamic> item,
    AppLocalizations? loc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          loc?.translate('api_keys_dialog_revoke_title') ?? 'Revoke API key',
        ),
        content: Text(
          (loc?.translate('api_keys_dialog_revoke_description') ??
                  'Revoke "{name}"? This action cannot be undone.')
              .replaceAll('{name}', (item['name'] ?? '').toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              loc?.translate('api_keys_confirm_revoke') ?? 'Confirm revoke',
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _revoke((item['id'] as num).toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context).user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (user == null) {
      return LoginRequiredView(
        message: loc?.translate('login_first') ?? 'Please login first.',
        onAction: () => context.go('/login'),
      );
    }

    if (_loading) {
      return const _ApiKeysLoadingState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc?.translate('api_keys_title') ?? 'Create API key',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc?.translate('api_keys_description') ??
                      'Use API keys for non-admin endpoints. Admin routes still require normal user auth.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Button(
                  onPressed: _creating
                      ? null
                      : () => _showCreateDialog(context, loc),
                  icon: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                  text: _creating
                      ? (loc?.translate('api_keys_creating') ?? 'Creating...')
                      : (loc?.translate('api_keys_create_button') ??
                            'Create key'),
                ),
                if ((_latestSecret ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc?.translate('api_keys_copy_secret_hint') ??
                              'Copy this secret now. It will not be shown again.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _latestSecret!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          variant: ButtonVariant.secondary,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _latestSecret!),
                            );
                            if (!context.mounted) return;
                            SnackBarHelper.showSuccess(
                              context,
                              title:
                                  loc?.translate('settings_api_key') ??
                                  'API Key',
                              message:
                                  loc?.translate('api_keys_copied') ??
                                  'API key copied',
                            );
                          },
                          text: loc?.translate('copy') ?? 'Copy',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc?.translate('api_keys_existing_title') ?? 'Existing keys',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if ((_error ?? '').isNotEmpty)
                  Text(_error!, style: TextStyle(color: scheme.error))
                else if (_items.isEmpty)
                  Text(
                    loc?.translate('api_keys_empty') ?? 'No API keys yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  ..._items.map((item) {
                    final revoked = (item['revoked_at'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (item['name'] ??
                                          (loc?.translate('api_keys_unnamed') ??
                                              'Unnamed key'))
                                      .toString(),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (revoked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    loc?.translate('api_keys_revoked') ??
                                        'Revoked',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item['key_prefix'] ?? ''}...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (((item['description'] ?? '').toString().trim())
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(item['description'].toString()),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${loc?.translate('api_keys_created_at') ?? 'Created'}: ${_formatDate(item['created_at'], loc)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${loc?.translate('api_keys_last_used') ?? 'Last used'}: ${_formatDate(item['last_used_at'], loc)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Button(
                            variant: ButtonVariant.outline,
                            onPressed: revoked || _revoking
                                ? null
                                : () => _confirmRevoke(context, item, loc),
                            text:
                                loc?.translate('api_keys_revoke_button') ??
                                'Revoke',
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateApiKeyDialog extends StatefulWidget {
  final AppLocalizations? loc;
  final bool creating;
  final Future<void> Function({
    required String name,
    required String description,
  })
  onCreate;

  const _CreateApiKeyDialog({
    required this.loc,
    required this.creating,
    required this.onCreate,
  });

  @override
  State<_CreateApiKeyDialog> createState() => _CreateApiKeyDialogState();
}

class _CreateApiKeyDialogState extends State<_CreateApiKeyDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final creating = widget.creating || _submitting;
    final canSubmit = _nameController.text.trim().isNotEmpty && !creating;

    return AlertDialog(
      title: Text(
        loc?.translate('api_keys_dialog_create_title') ?? 'Create API key',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc?.translate('api_keys_dialog_create_description') ??
                  'Add a name and an optional description so you can recognize this key later.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc?.translate('api_keys_name_label') ?? 'Key name',
                hintText:
                    loc?.translate('api_keys_name_placeholder') ??
                    'Production script',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText:
                    loc?.translate('api_keys_description_label') ??
                    'Description',
                hintText:
                    loc?.translate('optional_description') ??
                    'Optional description',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: creating ? null : () => Navigator.of(context).pop(),
          child: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () async {
                  final navigator = Navigator.of(context);
                  setState(() {
                    _submitting = true;
                  });
                  await widget.onCreate(
                    name: _nameController.text,
                    description: _descriptionController.text,
                  );
                  if (!mounted) return;
                  setState(() {
                    _submitting = false;
                  });
                  navigator.pop();
                }
              : null,
          child: Text(
            creating
                ? (loc?.translate('api_keys_creating') ?? 'Creating...')
                : (loc?.translate('api_keys_confirm_create') ?? 'Create key'),
          ),
        ),
      ],
    );
  }
}

class _ApiKeysLoadingState extends StatelessWidget {
  const _ApiKeysLoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 20),
            child: CircularProgressIndicator(color: scheme.primary),
          ),
        ),
        ...List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 16),
            child: Shimmer.fromColors(
              baseColor: scheme.surfaceContainerHigh,
              highlightColor: scheme.surfaceContainerHighest,
              child: CustomCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 96,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
