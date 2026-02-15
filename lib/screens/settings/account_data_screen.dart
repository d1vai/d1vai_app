import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/login_required_view.dart';
import '../../widgets/snackbar_helper.dart';

class AccountDataScreen extends StatelessWidget {
  const AccountDataScreen({super.key});

  static const String _supportEmail = 'dev@d1v.ai';

  String _exportTemplate(BuildContext context, String? email) {
    final loc = AppLocalizations.of(context);
    final e = (email ?? '').trim().isEmpty ? '<your email>' : email!.trim();
    final template =
        loc?.translate('account_data_export_template') ??
        'Request: Data Export\\n'
            'Account: {email}\\n'
            'Please export my account data (profile, projects, billing).\\n'
            'Contact: {support_email}';
    return template
        .replaceAll('{email}', e)
        .replaceAll('{support_email}', _supportEmail);
  }

  String _deleteTemplate(BuildContext context, String? email) {
    final loc = AppLocalizations.of(context);
    final e = (email ?? '').trim().isEmpty ? '<your email>' : email!.trim();
    final template =
        loc?.translate('account_data_delete_template') ??
        'Request: Account Deletion\\n'
            'Account: {email}\\n'
            'Please delete my account and associated data.\\n'
            'I understand this action may be irreversible.\\n'
            'Contact: {support_email}';
    return template
        .replaceAll('{email}', e)
        .replaceAll('{support_email}', _supportEmail);
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: AppLocalizations.of(context)?.translate('copied') ?? 'Copied',
      message:
          AppLocalizations.of(
            context,
          )?.translate('account_data_request_template_copied') ??
          'Request template copied to clipboard',
    );
  }

  Future<void> _showSupportDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc?.translate('contact_support') ?? 'Contact Support'),
        content: Text(
          (loc?.translate('account_data_support_dialog_message') ??
                  'Please contact {support_email} for this request.')
              .replaceAll('{support_email}', _supportEmail),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc?.translate('confirm') ?? 'OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('account_data_title') ?? 'Account & Data'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return LoginRequiredView(
              variant: LoginRequiredVariant.full,
              message:
                  loc?.translate('login_required_settings_message') ??
                  'You need to log in to manage account settings.',
              onAction: () => context.go('/login'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc?.translate('account_data_export_title') ??
                            'Data Export',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc?.translate('account_data_export_description') ??
                            'Export is currently handled by support. We provide a template you can copy and send.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copy(
                                context,
                                _exportTemplate(context, user.email),
                              ),
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(
                                loc?.translate(
                                      'account_data_copy_request_template',
                                    ) ??
                                    'Copy request template',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showSupportDialog(context),
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: Text(
                              loc?.translate('contact_support') ?? 'Support',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc?.translate('account_data_delete_title') ??
                            'Account Deletion',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc?.translate('account_data_delete_description') ??
                            'Account deletion is currently handled by support. Please review the legal restrictions before requesting deletion.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copy(
                                context,
                                _deleteTemplate(context, user.email),
                              ),
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(
                                loc?.translate(
                                      'account_data_copy_request_template',
                                    ) ??
                                    'Copy request template',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/docs/legal-restrictions'),
                            icon: const Icon(Icons.gavel, size: 18),
                            label: Text(
                              loc?.translate('account_data_legal') ?? 'Legal',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final shouldProceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  loc?.translate('account_data_delete_title') ??
                                      'Account Deletion',
                                ),
                                content: Text(
                                  (loc?.translate(
                                            'account_data_delete_confirm_message',
                                          ) ??
                                          'This will contact {support_email} to request account deletion. Deletion may be irreversible. Continue?')
                                      .replaceAll(
                                        '{support_email}',
                                        _supportEmail,
                                      ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(
                                      loc?.translate('cancel') ?? 'Cancel',
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(
                                      loc?.translate('confirm') ?? 'Continue',
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (shouldProceed != true) return;
                            if (!context.mounted) return;
                            await _showSupportDialog(context);
                          },
                          icon: const Icon(Icons.support_agent),
                          label: Text(
                            loc?.translate(
                                  'account_data_contact_support_delete',
                                ) ??
                                'Contact support to delete account',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
