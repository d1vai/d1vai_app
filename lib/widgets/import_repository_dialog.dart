import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/d1vai_service.dart';
import '../services/github_service.dart';
import 'adaptive_modal.dart';
import 'button.dart';
import 'progress_widget.dart';
import 'snackbar_helper.dart';

class ImportRepositoryDialog extends StatefulWidget {
  final Map<String, dynamic> repository;
  final int installationId;

  const ImportRepositoryDialog({
    super.key,
    required this.repository,
    required this.installationId,
  });

  @override
  State<ImportRepositoryDialog> createState() => _ImportRepositoryDialogState();
}

class _ImportRepositoryDialogState extends State<ImportRepositoryDialog> {
  final GitHubService _githubService = GitHubService();
  final D1vaiService _d1vaiService = D1vaiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _projectNameController;
  late final TextEditingController _projectDescriptionController;
  late final TextEditingController _rootDirectoryController;

  bool _isImporting = false;
  bool _waitingForDeploy = false;
  bool _deployReady = false;
  bool _isConfiguringRootDirectory = false;
  String? _importedProjectId;
  Map<String, dynamic>? _importAutoDeploy;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  bool get _isBusy =>
      _isImporting || _waitingForDeploy || _isConfiguringRootDirectory;

  bool get _canClose => !_waitingForDeploy;

  @override
  void initState() {
    super.initState();
    final repoName = (widget.repository['name'] ?? '').toString();
    final repoDescription = (widget.repository['description'] ?? '').toString();
    _projectNameController = TextEditingController(text: repoName);
    _projectDescriptionController = TextEditingController(
      text: repoDescription.isEmpty
          ? 'Imported from GitHub: ${(widget.repository['full_name'] ?? repoName).toString()}'
          : repoDescription,
    );
    _rootDirectoryController = TextEditingController();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _rootDirectoryController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _normalizeImportResult(Map<String, dynamic>? response) {
    final root = response ?? <String, dynamic>{};
    final data = root['data'];
    final payload = data is Map<String, dynamic>
        ? data
        : data is Map
        ? data.cast<String, dynamic>()
        : root;
    final projectRaw = payload['project'];
    final project = projectRaw is Map<String, dynamic>
        ? projectRaw
        : projectRaw is Map
        ? projectRaw.cast<String, dynamic>()
        : payload;
    final importAutoDeployRaw = payload['import_auto_deploy'];
    final importAutoDeploy = importAutoDeployRaw is Map<String, dynamic>
        ? importAutoDeployRaw
        : importAutoDeployRaw is Map
        ? importAutoDeployRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final id =
        project['id']?.toString() ??
        payload['project_id']?.toString() ??
        payload['id']?.toString();

    return {
      'project': project,
      'project_id': id,
      'import_auto_deploy': importAutoDeploy,
    };
  }

  List<String> get _deployTips {
    if ((_importAutoDeploy?['monorepo_candidates'] as List?)?.isNotEmpty ==
        true) {
      return <String>[
        _t('github_import_progress_repo_imported', 'Repository imported'),
        _t(
          'github_import_progress_choose_root',
          'Select the app root directory',
        ),
        _t(
          'github_import_progress_preview_after_root',
          'Preview deploy will start after configuration',
        ),
      ];
    }
    return <String>[
      _t('github_import_progress_import', 'Importing repository'),
      _t(
        'github_import_progress_prepare_preview',
        'Preparing preview deployment',
      ),
      _t(
        'github_import_progress_wait_preview',
        'Waiting for preview to become ready',
      ),
    ];
  }

  Future<void> _waitForPreviewThenNavigate(String projectId) async {
    if (!mounted) return;
    setState(() {
      _waitingForDeploy = true;
      _deployReady = false;
    });

    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (mounted && DateTime.now().isBefore(deadline)) {
      try {
        final status = await _d1vaiService.getProjectPreviewStatus(projectId);
        if (status['success'] == true) {
          if (!mounted) return;
          setState(() {
            _deployReady = true;
          });
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          final router = GoRouter.of(context);
          Navigator.of(context).pop(true);
          Future.microtask(() => router.push('/projects/$projectId/chat'));
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (!mounted) return;
    setState(() {
      _waitingForDeploy = false;
    });
    SnackBarHelper.showInfo(
      context,
      title: _t('github_import_sheet_title', 'Import Repository'),
      message: _t(
        'github_import_opening_chat',
        'Project imported. Preview is still starting, opening chat now.',
      ),
    );
    final router = GoRouter.of(context);
    Navigator.of(context).pop(true);
    Future.microtask(() => router.push('/projects/$projectId/chat'));
  }

  Future<void> _finishImportNavigation(String projectId) async {
    final autoDeployQueued = _importAutoDeploy?['auto_deploy_queued'] == true;
    final isDeployable = _importAutoDeploy?['is_deployable'] == true;
    final monorepoCandidates =
        (_importAutoDeploy?['monorepo_candidates'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];

    if (monorepoCandidates.isNotEmpty) {
      setState(() {
        _rootDirectoryController.text = monorepoCandidates.first;
      });
      return;
    }

    if (autoDeployQueued && isDeployable) {
      await _waitForPreviewThenNavigate(projectId);
      return;
    }

    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop(true);
    Future.microtask(() => router.push('/projects/$projectId/chat'));
  }

  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final repoId = (widget.repository['id'] as num?)?.toInt();
      if (repoId == null) throw Exception('Missing repository id');

      final result = await _githubService.importProjectFromGitHubApp(
        installationId: widget.installationId,
        repositoryId: repoId,
        projectName: _projectNameController.text.trim(),
        projectDescription: _projectDescriptionController.text.trim(),
      );

      final normalized = _normalizeImportResult(result);
      final projectId = (normalized['project_id'] ?? '').toString().trim();
      if (projectId.isEmpty) {
        throw Exception('Failed to get project ID');
      }

      final importAutoDeploy =
          normalized['import_auto_deploy'] is Map<String, dynamic>
          ? normalized['import_auto_deploy'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _importedProjectId = projectId;
        _importAutoDeploy = importAutoDeploy;
      });

      SnackBarHelper.showSuccess(
        context,
        title: _t('github_import_sheet_title', 'Import Repository'),
        message: _t(
          'github_import_success_message',
          'Repository imported successfully',
        ),
      );

      await _finishImportNavigation(projectId);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('github_import_failed_title', 'Import Failed'),
        message:
            '${_t('github_import_failed_message', 'Failed to import repository')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _handleConfigureRootDirectory() async {
    final projectId = (_importedProjectId ?? '').trim();
    final rootDirectory = _rootDirectoryController.text.trim();
    if (projectId.isEmpty || rootDirectory.isEmpty) return;

    setState(() {
      _isConfiguringRootDirectory = true;
    });

    try {
      await _d1vaiService.configureProjectRootDirectory(
        projectId,
        rootDirectory: rootDirectory,
        triggerDeploy: true,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('github_import_deploy_title', 'Deploy'),
        message: _t(
          'github_import_root_saved',
          'Root directory saved. Preview deploy started.',
        ),
      );
      setState(() {
        _importAutoDeploy = <String, dynamic>{
          ...?_importAutoDeploy,
          'is_deployable': true,
          'auto_deploy_queued': true,
          'monorepo_candidates': const <String>[],
        };
      });
      await _waitForPreviewThenNavigate(projectId);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('github_import_deploy_title', 'Deploy'),
        message:
            '${_t('github_import_root_failed', 'Failed to configure root directory')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguringRootDirectory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fullName =
        (widget.repository['full_name'] ?? widget.repository['name'] ?? '')
            .toString();
    final language = (widget.repository['language'] ?? '').toString().trim();
    final isPrivate =
        widget.repository['is_private'] == true ||
        widget.repository['private'] == true;
    final monorepoCandidates =
        (_importAutoDeploy?['monorepo_candidates'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final isMonorepoSetup = monorepoCandidates.isNotEmpty;
    final primaryLabel = isMonorepoSetup
        ? (_isConfiguringRootDirectory
              ? _t(
                  'github_import_action_starting_preview',
                  'Starting preview deploy…',
                )
              : _t(
                  'github_import_action_start_preview',
                  'Start Preview Deploy',
                ))
        : (_isImporting
              ? _t('github_import_action_importing', 'Importing project…')
              : (_waitingForDeploy
                    ? _t('github_import_action_opening_chat', 'Opening chat…')
                    : _t('github_import_action_import', 'Import Project')));

    return AdaptiveModalContainer(
      maxWidth: 560,
      mobileMaxHeightFactor: 0.97,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.18
                                  : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.download_for_offline_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  'github_import_sheet_title',
                                  'Import Repository',
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t(
                                  'github_import_sheet_subtitle',
                                  'Create a new project from this GitHub repository and keep preview deploy in flow.',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.88),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _canClose
                              ? () => Navigator.of(context).pop()
                              : null,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.surfaceContainerHighest.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.34
                                  : 0.72,
                            ),
                            colorScheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.78
                                  : 0.98,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.42
                                : 0.58,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (language.isNotEmpty)
                                _MetaChip(label: language),
                              _MetaChip(
                                label: isPrivate
                                    ? _t(
                                        'github_import_repo_private',
                                        'private',
                                      )
                                    : _t('github_import_repo_public', 'public'),
                              ),
                              _MetaChip(
                                label:
                                    _t(
                                      'github_import_repo_branch',
                                      'branch {branch}',
                                    ).replaceAll(
                                      '{branch}',
                                      (widget.repository['default_branch'] ??
                                              'main')
                                          .toString(),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isImporting || _waitingForDeploy || _deployReady) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.13
                                : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colorScheme.primary.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.20
                                  : 0.14,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Icon(
                                    _deployReady
                                        ? Icons.check_rounded
                                        : Icons.bolt_rounded,
                                    size: 14,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _deployReady
                                      ? _t(
                                          'github_import_ready_title',
                                          'Preview is ready',
                                        )
                                      : _t(
                                          'github_import_in_progress_title',
                                          'Import in progress',
                                        ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ProgressWidget(
                              tipList: _deployTips,
                              completed: _deployReady,
                              preCompleteDuration: const Duration(seconds: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _projectNameController,
                      enabled: !_isBusy,
                      decoration: InputDecoration(
                        labelText: _t(
                          'github_import_project_name',
                          'Project Name',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _t(
                            'github_import_project_name_required',
                            'Project name is required',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _projectDescriptionController,
                      enabled: !_isBusy,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _t(
                          'github_import_project_description',
                          'Project Description',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (monorepoCandidates.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.22
                                : 0.56,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: 18,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t(
                                  'github_import_monorepo_notice',
                                  'This repository looks like a monorepo. Choose the app root directory before preview deploy starts.',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer
                                      .withValues(alpha: 0.88),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _rootDirectoryController.text.trim().isEmpty
                            ? null
                            : _rootDirectoryController.text.trim(),
                        items: monorepoCandidates
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: _isConfiguringRootDirectory
                            ? null
                            : (value) {
                                _rootDirectoryController.text = (value ?? '')
                                    .trim();
                              },
                        decoration: InputDecoration(
                          labelText: _t(
                            'github_import_root_directory',
                            'Root Directory',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.94 : 0.98,
                ),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.52,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Button(
                      variant: ButtonVariant.secondary,
                      onPressed: _canClose
                          ? () => Navigator.of(context).pop()
                          : null,
                      disabledBackgroundColor:
                          colorScheme.surfaceContainerHighest,
                      disabledForegroundColor: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.76),
                      text: _t('cancel', 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Button(
                      onPressed: isMonorepoSetup
                          ? (_isConfiguringRootDirectory
                                ? null
                                : _handleConfigureRootDirectory)
                          : (_isBusy ? null : _handleImport),
                      disabledBackgroundColor: colorScheme.primary.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.74
                            : 0.88,
                      ),
                      disabledForegroundColor: colorScheme.onPrimary.withValues(
                        alpha: 0.98,
                      ),
                      icon: _isBusy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              isMonorepoSetup
                                  ? Icons.rocket_launch_outlined
                                  : Icons.download_rounded,
                              size: 18,
                            ),
                      text: primaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}
