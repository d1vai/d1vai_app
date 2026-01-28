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

  String _exportTemplate(String? email) {
    final e = (email ?? '').trim().isEmpty ? '<your email>' : email!.trim();
    return 'Request: Data Export\\n'
        'Account: $e\\n'
        'Please export my account data (profile, projects, billing).';
  }

  String _deleteTemplate(String? email) {
    final e = (email ?? '').trim().isEmpty ? '<your email>' : email!.trim();
    return 'Request: Account Deletion\\n'
        'Account: $e\\n'
        'Please delete my account and associated data.\\n'
        'I understand this action may be irreversible.';
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: AppLocalizations.of(context)?.translate('copied') ?? 'Copied',
      message: 'Copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Data'),
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
                        'Data Export',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
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
                                _exportTemplate(user.email),
                              ),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy request template'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/settings/help'),
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: const Text('Support'),
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
                        'Account Deletion',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
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
                                _deleteTemplate(user.email),
                              ),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy request template'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/docs/legal-restrictions'),
                            icon: const Icon(Icons.gavel, size: 18),
                            label: const Text('Legal'),
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
                                title: const Text('Request account deletion'),
                                content: const Text(
                                  'This will contact support to request account deletion. '
                                  'Deletion may be irreversible. Continue?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Continue'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldProceed != true) return;
                            if (!context.mounted) return;
                            context.push('/settings/help');
                          },
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Contact support to delete account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
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
