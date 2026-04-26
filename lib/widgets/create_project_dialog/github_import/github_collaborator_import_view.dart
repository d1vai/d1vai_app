import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../input.dart';
import '../../button.dart';
import 'github_import_utils.dart';

class GithubCollaboratorImportView extends StatelessWidget {
  final int step; // 1..3
  final bool loading;
  final String errorText;
  final String botUsername;
  final bool invitationAccepted;
  final bool accessVerified;
  final Map<String, dynamic>? repoInfo;
  final TextEditingController repoUrlController;
  final TextEditingController projectNameController;
  final ValueChanged<String> onRepoUrlChanged;
  final VoidCallback onCopyBotUsername;
  final VoidCallback onOpenSettings;
  final VoidCallback onAcceptInvitation;
  final VoidCallback onVerifyAccess;
  final VoidCallback onImportProject;

  const GithubCollaboratorImportView({
    super.key,
    required this.step,
    required this.loading,
    required this.errorText,
    required this.botUsername,
    required this.invitationAccepted,
    required this.accessVerified,
    required this.repoInfo,
    required this.repoUrlController,
    required this.projectNameController,
    required this.onRepoUrlChanged,
    required this.onCopyBotUsername,
    required this.onOpenSettings,
    required this.onAcceptInvitation,
    required this.onVerifyAccess,
    required this.onImportProject,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('github_collaborator'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc?.translate('create_project_github_guided_title') ??
                    'Guided GitHub import (3 steps)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          (loc?.translate('create_project_step_of_3') ?? 'Step {step} of 3')
              .replaceAll('{step}', '$step'),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (step.clamp(1, 3)) / 3.0,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 16),
        if (errorText.isNotEmpty) ...[
          _ErrorBanner(text: errorText),
          const SizedBox(height: 16),
        ],
        if (step == 1)
          _GithubStep1(
            repoUrlController: repoUrlController,
            onRepoUrlChanged: onRepoUrlChanged,
            botUsername: botUsername,
            onCopyBotUsername: onCopyBotUsername,
            loading: loading,
            errorText: errorText,
            onOpenSettings: onOpenSettings,
          )
        else if (step == 2)
          _GithubStep2(
            repoUrlController: repoUrlController,
            botUsername: botUsername,
            onCopyBotUsername: onCopyBotUsername,
            loading: loading,
            invitationAccepted: invitationAccepted,
            onAcceptInvitation: onAcceptInvitation,
          )
        else
          _GithubStep3(
            repoUrlController: repoUrlController,
            projectNameController: projectNameController,
            repoInfo: repoInfo,
            loading: loading,
            accessVerified: accessVerified,
            onVerifyAccess: onVerifyAccess,
            onImportProject: onImportProject,
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;

  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BotUsernameCard extends StatelessWidget {
  final String botUsername;
  final VoidCallback onCopy;
  final AppLocalizations? loc;

  const _BotUsernameCard({
    required this.botUsername,
    required this.onCopy,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc?.translate('create_project_github_bot_username') ??
                      'GitHub Bot Username',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  botUsername,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
            tooltip: loc?.translate('copy') ?? 'Copy',
          ),
        ],
      ),
    );
  }
}

class _GithubStep1 extends StatelessWidget {
  final TextEditingController repoUrlController;
  final ValueChanged<String> onRepoUrlChanged;
  final String botUsername;
  final VoidCallback onCopyBotUsername;
  final bool loading;
  final String errorText;
  final VoidCallback onOpenSettings;

  const _GithubStep1({
    required this.repoUrlController,
    required this.onRepoUrlChanged,
    required this.botUsername,
    required this.onCopyBotUsername,
    required this.loading,
    required this.errorText,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final repoFullName = parseGithubRepoFullName(repoUrlController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Input(
          controller: repoUrlController,
          onChanged: onRepoUrlChanged,
          labelText:
              loc?.translate('create_project_repository_url') ??
              'Repository URL',
          hintText: 'https://github.com/owner/repo',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.link),
          errorText: (errorText.isNotEmpty && repoFullName == null)
              ? errorText
              : null,
        ),
        const SizedBox(height: 12),
        _BotUsernameCard(
          botUsername: botUsername,
          onCopy: onCopyBotUsername,
          loc: loc,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Button(
            onPressed: (loading || repoFullName == null)
                ? null
                : onOpenSettings,
            disabled: loading || repoFullName == null,
            variant: ButtonVariant.defaultVariant,
            size: ButtonSize.defaultSize,
            text:
                loc?.translate('create_project_open_github_settings') ??
                'Open GitHub Settings',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _GithubStep2 extends StatelessWidget {
  final TextEditingController repoUrlController;
  final String botUsername;
  final VoidCallback onCopyBotUsername;
  final bool loading;
  final bool invitationAccepted;
  final VoidCallback onAcceptInvitation;

  const _GithubStep2({
    required this.repoUrlController,
    required this.botUsername,
    required this.onCopyBotUsername,
    required this.loading,
    required this.invitationAccepted,
    required this.onAcceptInvitation,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repoFullName = parseGithubRepoFullName(repoUrlController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (loc?.translate('create_project_accept_invitation_hint') ??
                  'Add "{bot}" as a collaborator in GitHub repo settings, then tap "Accept Invitation".')
              .replaceAll('{bot}', botUsername),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _BotUsernameCard(
          botUsername: botUsername,
          onCopy: onCopyBotUsername,
          loc: loc,
        ),
        const SizedBox(height: 12),
        if (repoFullName != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              repoFullName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Button(
            onPressed: loading ? null : onAcceptInvitation,
            disabled: loading,
            variant: ButtonVariant.defaultVariant,
            size: ButtonSize.defaultSize,
            text: invitationAccepted
                ? (loc?.translate('create_project_invitation_accepted') ??
                      'Invitation Accepted')
                : (loc?.translate('create_project_accept_invitation') ??
                      'Accept Invitation'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _GithubStep3 extends StatelessWidget {
  final TextEditingController repoUrlController;
  final TextEditingController projectNameController;
  final Map<String, dynamic>? repoInfo;
  final bool loading;
  final bool accessVerified;
  final VoidCallback onVerifyAccess;
  final VoidCallback onImportProject;

  const _GithubStep3({
    required this.repoUrlController,
    required this.projectNameController,
    required this.repoInfo,
    required this.loading,
    required this.accessVerified,
    required this.onVerifyAccess,
    required this.onImportProject,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repoFullName = parseGithubRepoFullName(repoUrlController.text);
    final canImport =
        repoFullName != null && repoInfo != null && accessVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Button(
            onPressed: loading ? null : onVerifyAccess,
            disabled: loading,
            variant: ButtonVariant.defaultVariant,
            size: ButtonSize.defaultSize,
            text: accessVerified
                ? (loc?.translate('create_project_access_verified') ??
                      'Access Verified')
                : (loc?.translate('create_project_verify_access') ??
                      'Verify Access'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (repoInfo != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (repoInfo?['repository_full_name'] ??
                              repoInfo?['repository_name'] ??
                              repoFullName)
                          ?.toString() ??
                      '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (repoInfo?['description'] ?? '').toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Input(
          controller: projectNameController,
          labelText:
              loc?.translate('create_project_project_name') ?? 'Project Name',
          hintText:
              loc?.translate('create_project_default_repo_name') ??
              'Default: repository name',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.folder),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Button(
            onPressed: (loading || !canImport) ? null : onImportProject,
            disabled: loading || !canImport,
            variant: ButtonVariant.defaultVariant,
            size: ButtonSize.defaultSize,
            text:
                loc?.translate('create_project_import_project_action') ??
                'Import Project',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
