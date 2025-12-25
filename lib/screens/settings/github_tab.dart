import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/project_provider.dart';
import '../../services/d1vai_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/snackbar_helper.dart';

/// GitHub integration tab for the settings screen.
class SettingsGithubTab extends StatelessWidget {
  const SettingsGithubTab({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CustomCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.code,
                      color: AppColors.primaryBrand,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc?.translate('github_integration') ??
                                'GitHub Integration',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc?.translate('github_connect_description') ??
                                'Connect your GitHub account to import repositories',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Button(
                    onPressed: () {
                      // Navigate to GitHub settings screen.
                      context.push('/settings/github');
                    },
                    icon: const Icon(Icons.link),
                    text: loc?.translate('connect_github') ?? 'Connect GitHub',
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CustomCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.info),
                title: Text(
                  loc?.translate('sync_repositories') ?? 'Sync Repositories',
                ),
                subtitle: Text(
                  loc?.translate('sync_subtitle') ??
                      'Update your repository list',
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                onTap: () {
                  SnackBarHelper.showInfo(
                    context,
                    title: loc?.translate('syncing') ?? 'Syncing',
                    message:
                        loc?.translate('syncing_message') ??
                        'Syncing repositories...',
                  );

                  Provider.of<ProjectProvider>(context, listen: false)
                      .refresh()
                      .then((_) {
                        if (!context.mounted) return;
                        SnackBarHelper.showSuccess(
                          context,
                          title: loc?.translate('success') ?? 'Success',
                          message:
                              loc?.translate('sync_success') ??
                              'Repositories synced successfully',
                        );
                      })
                      .catchError((error) {
                        if (!context.mounted) return;
                        SnackBarHelper.showError(
                          context,
                          title: loc?.translate('error') ?? 'Error',
                          message:
                              '${loc?.translate('sync_failed') ?? "Failed to sync repositories"}: $error',
                        );
                      });
                },
              ),
              Divider(
                height: 1,
                color: isDark
                    ? AppColors.borderSubtleDark
                    : AppColors.borderLight,
              ),
              ListTile(
                leading: const Icon(
                  Icons.list,
                  color: AppColors.secondaryBrand,
                ),
                title: Text(
                  loc?.translate('import_repository') ?? 'Import Repository',
                ),
                subtitle: Text(
                  loc?.translate('import_subtitle') ??
                      'Import a public repository',
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                onTap: () {
                  _showImportRepositoryDialog(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showImportRepositoryDialog(BuildContext context) {
  final ownerController = TextEditingController();
  final repoController = TextEditingController();
  final projectNameController = TextEditingController();
  final loc = AppLocalizations.of(context);
  bool isImporting = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(
          loc?.translate('import_dialog_title') ?? 'Import Public Repository',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc?.translate('import_dialog_description') ??
                  'Enter the repository information you want to import',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ownerController,
              enabled: !isImporting,
              decoration: InputDecoration(
                labelText: loc?.translate('owner_label') ?? 'Owner',
                hintText:
                    loc?.translate('owner_hint') ?? 'username or organization',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repoController,
              enabled: !isImporting,
              decoration: InputDecoration(
                labelText: loc?.translate('repo_label') ?? 'Repository',
                hintText: loc?.translate('repo_hint') ?? 'repository-name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: projectNameController,
              enabled: !isImporting,
              decoration: InputDecoration(
                labelText:
                    loc?.translate('project_name_optional') ??
                    'Project Name (Optional)',
                hintText:
                    loc?.translate('project_name_hint') ??
                    'Leave empty to use repository name',
                border: const OutlineInputBorder(),
              ),
            ),
            if (isImporting) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(loc?.translate('importing') ?? 'Importing...'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: isImporting ? null : () => Navigator.pop(dialogContext),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: isImporting
                ? null
                : () {
                    final owner = ownerController.text.trim();
                    final repo = repoController.text.trim();

                    if (owner.isEmpty || repo.isEmpty) {
                      SnackBarHelper.showError(
                        dialogContext,
                        title: loc?.translate('error') ?? 'Error',
                        message:
                            loc?.translate('input_error_owner_repo') ??
                            'Please enter owner and repository name',
                      );
                      return;
                    }

                    setDialogState(() {
                      isImporting = true;
                    });

                    D1vaiService()
                        .importPublicRepoToOrg({
                          'owner': owner,
                          'repo': repo,
                          if (projectNameController.text.trim().isNotEmpty)
                            'name': projectNameController.text.trim(),
                        })
                        .then((_) {
                          if (!dialogContext.mounted) return;
                          SnackBarHelper.showSuccess(
                            dialogContext,
                            title: loc?.translate('success') ?? 'Success',
                            message:
                                loc?.translate('import_success') ??
                                'Repository imported successfully',
                          );

                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          Provider.of<ProjectProvider>(
                            context,
                            listen: false,
                          ).refresh();
                        })
                        .catchError((error) {
                          if (!dialogContext.mounted) return;
                          SnackBarHelper.showError(
                            dialogContext,
                            title: loc?.translate('error') ?? 'Error',
                            message:
                                '${loc?.translate('import_failed') ?? "Failed to import repository"}: $error',
                          );
                          setDialogState(() {
                            isImporting = false;
                          });
                        });
                  },
            child: isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc?.translate('import_action') ?? 'Import'),
          ),
        ],
      ),
    ),
  );
}
