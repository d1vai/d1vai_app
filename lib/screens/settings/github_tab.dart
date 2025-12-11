import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
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
                            'GitHub Integration',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your GitHub account to import repositories',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
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
                    text: 'Connect GitHub',
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
                title: const Text('Sync Repositories'),
                subtitle: const Text('Update your repository list'),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                onTap: () {
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Syncing',
                    message: 'Syncing repositories...',
                  );

                  Provider.of<ProjectProvider>(context, listen: false)
                      .refresh()
                      .then((_) {
                        if (!context.mounted) return;
                        SnackBarHelper.showSuccess(
                          context,
                          title: 'Success',
                          message: 'Repositories synced successfully',
                        );
                      })
                      .catchError((error) {
                        if (!context.mounted) return;
                        SnackBarHelper.showError(
                          context,
                          title: 'Error',
                          message: 'Failed to sync repositories: $error',
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
                title: const Text('Import Repository'),
                subtitle: const Text('Import a public repository'),
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
  bool isImporting = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Import Public Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the repository information you want to import',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ownerController,
              enabled: !isImporting,
              decoration: const InputDecoration(
                labelText: 'Owner',
                hintText: 'username or organization',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repoController,
              enabled: !isImporting,
              decoration: const InputDecoration(
                labelText: 'Repository',
                hintText: 'repository-name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: projectNameController,
              enabled: !isImporting,
              decoration: const InputDecoration(
                labelText: 'Project Name (Optional)',
                hintText: 'Leave empty to use repository name',
                border: OutlineInputBorder(),
              ),
            ),
            if (isImporting) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Importing...'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: isImporting ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
                        title: 'Error',
                        message: 'Please enter owner and repository name',
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
                            title: 'Success',
                            message: 'Repository imported successfully',
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
                            title: 'Error',
                            message: 'Failed to import repository: $error',
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
                : const Text('Import'),
          ),
        ],
      ),
    ),
  );
}
