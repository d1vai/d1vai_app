import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../widgets/login_required_view.dart';
import '../../widgets/snackbar_helper.dart';

class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});

  @override
  State<AccountDataScreen> createState() => _AccountDataScreenState();
}

class _AccountDataScreenState extends State<AccountDataScreen> {
  static const String _supportEmail = 'dev@d1v.ai';

  final D1vaiService _d1vaiService = D1vaiService();

  bool _isLoadingProjects = true;
  String? _projectsError;
  List<UserProject> _projects = const <UserProject>[];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsError = null;
    });

    try {
      final projects = await _d1vaiService.getUserProjects(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _projects = List<UserProject>.from(projects)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  String _exportTemplate(BuildContext context, String? email) {
    final loc = AppLocalizations.of(context);
    final e = (email ?? '').trim().isEmpty ? '<your email>' : email!.trim();
    final template =
        loc?.translate('account_data_export_template') ??
        'Request: Data Export\n'
            'Account: {email}\n'
            'Please export my account data (profile, projects, billing).\n'
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
        'Request: Account Deletion\n'
            'Account: {email}\n'
            'Please delete my account and associated data.\n'
            'I confirm that I have removed all projects from this account.\n'
            'I understand this action may be irreversible.\n'
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

  Future<void> _showSupportDialog(
    BuildContext context, {
    String? extraMessage,
  }) async {
    final loc = AppLocalizations.of(context);
    final base =
        (loc?.translate('account_data_support_dialog_message') ??
                'Please contact {support_email} for this request.')
            .replaceAll('{support_email}', _supportEmail);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc?.translate('contact_support') ?? 'Contact Support'),
        content: Text(
          extraMessage == null || extraMessage.trim().isEmpty
              ? base
              : '$base\n\n$extraMessage',
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

  Future<void> _handleDeletion(String? email) async {
    final loc = AppLocalizations.of(context);

    if (_isLoadingProjects) {
      SnackBarHelper.showInfo(
        context,
        title: loc?.translate('loading') ?? 'Loading',
        message: 'Checking your projects before account deletion...',
      );
      return;
    }

    if (_projectsError != null) {
      SnackBarHelper.showError(
        context,
        title: loc?.translate('error') ?? 'Error',
        message:
            'Could not verify your projects. Refresh the project list before continuing.',
      );
      return;
    }

    if (_projects.isNotEmpty) {
      SnackBarHelper.showError(
        context,
        title:
            loc?.translate('account_data_delete_title') ?? 'Account Deletion',
        message:
            'Delete or transfer all projects first. ${_projects.length} project(s) still belong to this account.',
      );
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.translate('account_data_delete_title') ?? 'Account Deletion',
        ),
        content: Text(
          'No projects remain on this account. We will copy your deletion request template, then log you out so the account can be finalized safely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc?.translate('confirm') ?? 'Continue'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) return;

    await _copy(context, _deleteTemplate(context, email));
    if (!mounted) return;

    await _showSupportDialog(
      context,
      extraMessage:
          'The deletion request template has been copied. Send it to $_supportEmail after reviewing it. You will be logged out after closing this dialog.',
    );
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.logout();
    } catch (_) {
      // Ignore logout cleanup failures and still send the user to login.
    }
    if (!mounted) return;
    context.go('/login');
  }

  Widget _buildProjectDeletionCard(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final hasProjects = _projects.isNotEmpty;
    final title = hasProjects
        ? 'Delete your projects first'
        : 'Project cleanup complete';
    final body = _isLoadingProjects
        ? 'Checking whether this account still owns any projects...'
        : _projectsError != null
        ? 'We could not verify your current projects. Please refresh before continuing.'
        : hasProjects
        ? 'Account deletion is blocked until every project is deleted or transferred out of this account.'
        : 'No projects remain on this account. You can continue with the deletion request flow below.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasProjects ? Icons.warning_amber_rounded : Icons.verified,
                  color: hasProjects
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isLoadingProjects)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!_isLoadingProjects &&
                _projectsError == null &&
                hasProjects) ...[
              const SizedBox(height: 12),
              ..._projects.take(5).map((project) {
                final subtitle = project.projectDescription.trim().isEmpty
                    ? project.status
                    : project.projectDescription.trim();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(project.projectName),
                  subtitle: Text(subtitle),
                );
              }),
              if (_projects.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'and ${_projects.length - 5} more project(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadProjects,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc?.translate('refresh') ?? 'Refresh'),
                  ),
                ),
                if (hasProjects) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/projects'),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open projects'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
              _buildProjectDeletionCard(context),
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
                        _projects.isNotEmpty
                            ? 'Delete or transfer every project before requesting account deletion.'
                            : (loc?.translate(
                                    'account_data_delete_description',
                                  ) ??
                                  'Account deletion is currently handled by support. Please review the legal restrictions before requesting deletion.'),
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
                          onPressed: () => _handleDeletion(user.email),
                          icon: const Icon(Icons.support_agent),
                          label: Text(
                            _projects.isNotEmpty
                                ? 'Delete projects before account deletion'
                                : (loc?.translate(
                                        'account_data_contact_support_delete',
                                      ) ??
                                      'Contact support to delete account'),
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
