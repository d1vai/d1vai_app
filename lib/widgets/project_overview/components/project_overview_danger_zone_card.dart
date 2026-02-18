import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../services/d1vai_service.dart';
import '../../progress_widget.dart';
import '../../snackbar_helper.dart';
import 'project_overview_card_shell.dart';

class ProjectOverviewDangerZoneCard extends StatelessWidget {
  final UserProject project;

  const ProjectOverviewDangerZoneCard({super.key, required this.project});

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

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
              title: Text(
                _t(
                  context,
                  'project_overview_danger_transfer_title',
                  'Transfer project',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        context,
                        'project_overview_danger_transfer_desc',
                        'Enter the recipient email to transfer ownership. You will lose access after transfer.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !transferring,
                      decoration: InputDecoration(
                        labelText: _t(
                          context,
                          'project_overview_danger_transfer_recipient',
                          'Recipient email',
                        ),
                        border: const OutlineInputBorder(),
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
                  child: Text(_t(context, 'cancel', 'Cancel')),
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
                              title: _t(dialogContext, 'success', 'Success'),
                              message: _t(
                                dialogContext,
                                'project_overview_danger_transfer_success',
                                'Project transferred',
                              ),
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
                              title: _t(dialogContext, 'error', 'Error'),
                              message: _t(
                                dialogContext,
                                'project_overview_danger_transfer_failed',
                                'Failed to transfer project',
                              ),
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
                      : Text(
                          _t(
                            context,
                            'project_overview_danger_transfer_action',
                            'Transfer',
                          ),
                        ),
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
              title: Text(
                _t(
                  context,
                  'project_overview_danger_delete_title',
                  'Delete project',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: deleting
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProgressWidget(
                            tipList: [
                              _t(
                                context,
                                'project_overview_danger_delete_progress_submit',
                                'Submitting delete request...',
                              ),
                              _t(
                                context,
                                'project_overview_danger_delete_progress_remove',
                                'Removing project resources...',
                              ),
                              _t(
                                context,
                                'project_overview_danger_delete_progress_cleanup',
                                'Final cleanup...',
                              ),
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
                            _t(
                              context,
                              'project_overview_danger_delete_in_progress',
                              'Deleting {name}...',
                            ).replaceAll('{name}', project.projectName),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(
                              context,
                              'project_overview_danger_delete_desc',
                              'This action cannot be undone. Please type the project name to confirm deletion.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              context,
                              'project_overview_danger_project_name',
                              'Project: {name}',
                            ).replaceAll('{name}', project.projectName),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: controller,
                            enabled: !deleting,
                            decoration: InputDecoration(
                              labelText: _t(
                                context,
                                'project_overview_danger_delete_confirm_label',
                                'Type project name to confirm',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          if (controller.text.isNotEmpty &&
                              controller.text != project.projectName) ...[
                            const SizedBox(height: 8),
                            Text(
                              _t(
                                context,
                                'project_overview_danger_delete_name_mismatch',
                                'Name does not match.',
                              ),
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
                  child: Text(_t(context, 'cancel', 'Cancel')),
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
                              title: _t(dialogContext, 'success', 'Success'),
                              message: _t(
                                dialogContext,
                                'project_overview_danger_delete_success',
                                'Deleted {name}',
                              ).replaceAll('{name}', project.projectName),
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
                              title: _t(dialogContext, 'error', 'Error'),
                              message: _t(
                                dialogContext,
                                'project_overview_danger_delete_failed',
                                'Failed to delete project',
                              ),
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
                      : Text(_t(context, 'delete', 'Delete')),
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ProjectOverviewCardShell(
      accentColor: colorScheme.error,
      borderColor: colorScheme.error.withValues(alpha: isDark ? 0.30 : 0.22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                _t(context, 'project_overview_danger_title', 'Danger zone'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colorScheme.tertiary.withValues(alpha: isDark ? 0.14 : 0.08),
                colorScheme.surface,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.32 : 0.34,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: colorScheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          context,
                          'project_overview_danger_transfer_title',
                          'Transfer project',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showTransferDialog(context),
                  icon: const Icon(Icons.arrow_right_alt),
                  label: Text(
                    _t(
                      context,
                      'project_overview_danger_transfer_action',
                      'Transfer',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colorScheme.error.withValues(alpha: isDark ? 0.12 : 0.06),
                colorScheme.surface,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.error.withValues(
                  alpha: isDark ? 0.26 : 0.20,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          context,
                          'project_overview_danger_delete_title',
                          'Delete project',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  icon: const Icon(Icons.delete),
                  label: Text(_t(context, 'delete', 'Delete')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
