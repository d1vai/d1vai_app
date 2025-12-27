import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../services/d1vai_service.dart';
import '../../progress_widget.dart';
import '../../snackbar_helper.dart';

class ProjectOverviewDangerZoneCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewDangerZoneCard({super.key, required this.project});

  bool _isValidEmail(String email) {
    final e = email.trim();
    return RegExp(r'^.+@.+\..+$').hasMatch(e);
  }

  Future<void> _showTransferDialog(BuildContext context) async {
    final parentContext = context;
    final controller = TextEditingController();
    var transferring = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Transfer project'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the recipient email to transfer ownership. You will lose access after transfer.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !transferring,
                      decoration: const InputDecoration(
                        labelText: 'Recipient email',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: transferring
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: transferring || !_isValidEmail(controller.text)
                      ? null
                      : () async {
                          setDialogState(() {
                            transferring = true;
                          });
                          try {
                            final service = D1vaiService();
                            await service.transferProject(
                              project.id,
                              targetEmail: controller.text.trim(),
                            );
                            if (!dialogContext.mounted) return;
                            SnackBarHelper.showSuccess(
                              dialogContext,
                              title: 'Success',
                              message: 'Project transferred',
                            );
                            await Provider.of<ProjectProvider>(
                              dialogContext,
                              listen: false,
                            ).refresh();
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            parentContext.go('/dashboard');
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            SnackBarHelper.showError(
                              dialogContext,
                              title: 'Error',
                              message: 'Failed to transfer project',
                            );
                            setDialogState(() {
                              transferring = false;
                            });
                          }
                        },
                  child: transferring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Transfer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final parentContext = context;
    final controller = TextEditingController();
    var deleting = false;
    var completed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !deleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete project'),
              content: SizedBox(
                width: 520,
                child: deleting
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProgressWidget(
                            tipList: const [
                              'Submitting delete request…',
                              'Removing project resources…',
                              'Final cleanup…',
                            ],
                            completed: completed,
                            width: 420,
                            onDone: () {
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              parentContext.go('/dashboard');
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Deleting ${project.projectName}…',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This action cannot be undone. Please type the project name to confirm deletion.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Project: ${project.projectName}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: controller,
                            enabled: !deleting,
                            decoration: const InputDecoration(
                              labelText: 'Type project name to confirm',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          if (controller.text.isNotEmpty &&
                              controller.text != project.projectName) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Name does not match.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: deleting || controller.text != project.projectName
                      ? null
                      : () async {
                          setDialogState(() {
                            deleting = true;
                            completed = false;
                          });
                          try {
                            final service = D1vaiService();
                            await service.deleteProject(project.id);
                            if (!dialogContext.mounted) return;
                            SnackBarHelper.showSuccess(
                              dialogContext,
                              title: 'Success',
                              message: 'Deleted ${project.projectName}',
                            );
                            await Provider.of<ProjectProvider>(
                              dialogContext,
                              listen: false,
                            ).refresh();
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              completed = true;
                            });
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            SnackBarHelper.showError(
                              dialogContext,
                              title: 'Error',
                              message: 'Failed to delete project',
                            );
                            setDialogState(() {
                              deleting = false;
                              completed = false;
                            });
                          }
                        },
                  child: deleting && !completed
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Danger zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer project',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transfer ownership to another user. You will lose access.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showTransferDialog(context),
                    icon: const Icon(Icons.arrow_right_alt),
                    label: const Text('Transfer'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete project',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Permanently delete this project and its resources.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

