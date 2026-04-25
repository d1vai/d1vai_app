import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/d1vai_service.dart';
import '../services/github_service.dart';
import 'adaptive_modal.dart';
import 'button.dart';
import 'card.dart';
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
      return const <String>[
        'Repository imported',
        'Select the app root directory',
        'Preview deploy will start after configuration',
      ];
    }
    return const <String>[
      'Importing repository',
      'Preparing preview deployment',
      'Waiting for preview to become ready',
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
      title: 'Import',
      message: 'Project imported. Preview is still starting, opening chat now.',
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
        title: 'Import',
        message: 'Repository imported successfully',
      );

      await _finishImportNavigation(projectId);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Import Failed',
        message: 'Failed to import repository: $e',
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
        title: 'Deploy',
        message: 'Root directory saved. Preview deploy started.',
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
        title: 'Deploy',
        message: 'Failed to configure root directory: $e',
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

    return AdaptiveModalContainer(
      maxWidth: 560,
      mobileMaxHeightFactor: 0.97,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download_for_offline,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Import Repository',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isImporting || _waitingForDeploy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                            if (language.isNotEmpty) _MetaChip(label: language),
                            _MetaChip(label: isPrivate ? 'private' : 'public'),
                            _MetaChip(
                              label:
                                  'branch ${(widget.repository['default_branch'] ?? 'main').toString()}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isImporting || _waitingForDeploy || _deployReady) ...[
                  ProgressWidget(
                    tipList: _deployTips,
                    completed: _deployReady,
                    preCompleteDuration: const Duration(seconds: 12),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _projectNameController,
                  enabled: !_isImporting && !_waitingForDeploy,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Project name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _projectDescriptionController,
                  enabled: !_isImporting && !_waitingForDeploy,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Project Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (monorepoCandidates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'This repository looks like a monorepo. Choose the app root directory before preview deploy starts.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _rootDirectoryController.text.trim().isEmpty
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
                    decoration: const InputDecoration(
                      labelText: 'Root Directory',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        variant: ButtonVariant.secondary,
                        onPressed: _isImporting || _waitingForDeploy
                            ? null
                            : () => Navigator.of(context).pop(),
                        text: 'Cancel',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Button(
                        onPressed: monorepoCandidates.isNotEmpty
                            ? (_isConfiguringRootDirectory
                                  ? null
                                  : _handleConfigureRootDirectory)
                            : (_isImporting || _waitingForDeploy
                                  ? null
                                  : _handleImport),
                        icon: Icon(
                          monorepoCandidates.isNotEmpty
                              ? Icons.rocket_launch
                              : Icons.download,
                          size: 18,
                        ),
                        text: monorepoCandidates.isNotEmpty
                            ? 'Start Preview Deploy'
                            : 'Import Project',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
