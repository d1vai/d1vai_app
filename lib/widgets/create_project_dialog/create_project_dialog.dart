import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../models/model_config.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../services/d1vai_service.dart';
import '../../services/model_config_service.dart';
import '../../services/workspace_service.dart';
import '../../utils/billing_errors.dart';
import '../snackbar_helper.dart';
import '../adaptive_modal.dart';
import '../insufficient_balance_dialog.dart';
import '../../l10n/app_localizations.dart';

import 'create_project_chooser_view.dart';
import 'create_project_dialog_shell.dart';
import 'create_project_import_local_view.dart';
import 'create_project_import_public_view.dart';
import 'create_project_loading_view.dart';
import 'create_project_new_ai_view.dart';
import 'github_import/github_collaborator_import_view.dart';
import 'github_import/github_import_utils.dart';

const String _autoTemplateRepo = 'auto';

/// 项目创建对话框
class CreateProjectDialog extends StatefulWidget {
  final Widget? trigger;
  final Function(UserProject)? onCreated;

  const CreateProjectDialog({super.key, this.trigger, this.onCreated});

  static Future<T?> show<T>(
    BuildContext context, {
    Function(UserProject)? onCreated,
  }) {
    return showAdaptiveModal<T>(
      context: context,
      builder: (context) => CreateProjectDialog(onCreated: onCreated),
    );
  }

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();
  final TextEditingController _localProjectNameController =
      TextEditingController();
  final TextEditingController _localProjectDescriptionController =
      TextEditingController();
  final WorkspaceService _workspaceService = WorkspaceService();
  final ModelConfigService _modelConfigService = ModelConfigService();

  _CreateProjectFlow _flow = _CreateProjectFlow.chooser;
  bool _isLoading = false;
  String _error = '';

  // New-project model selector state (align with d1vai web behavior)
  List<ModelInfo> _availableModels = <ModelInfo>[];
  String _selectedModelId = '';
  bool _isLoadingModels = false;
  bool _hasLoadedModelConfig = false;
  List<ProjectTemplateInfo> _availableTemplates = const <ProjectTemplateInfo>[];
  String _selectedTemplateRepo = _autoTemplateRepo;
  bool _isLoadingTemplates = false;
  WorkspacePhase _newProjectWorkspacePhase = WorkspacePhase.unknown;
  Timer? _newProjectWorkspacePollTimer;
  Timer? _newProjectModelRetryTimer;

  // GitHub collaborator import state (align with d1vai web QuickImportSetup)
  int _ghStep = 1; // 1..3
  String _ghBotUsername = 'd1v-dev';
  bool _ghLoading = false;
  String _ghError = '';
  bool _ghInvitationAccepted = false;
  bool _ghAccessVerified = false;
  Map<String, dynamic>? _ghRepoInfo;
  Uint8List? _localArchiveBytes;
  String? _localArchiveFileName;
  bool _localImportPrivate = true;
  final TextEditingController _ghRepoUrlController = TextEditingController();
  final TextEditingController _ghProjectNameController =
      TextEditingController();

  @override
  void dispose() {
    _newProjectWorkspacePollTimer?.cancel();
    _newProjectModelRetryTimer?.cancel();
    _descriptionController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _repoNameController.dispose();
    _localProjectNameController.dispose();
    _localProjectDescriptionController.dispose();
    _ghRepoUrlController.dispose();
    _ghProjectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isAnyLoading = _isLoading || _ghLoading;
    final showBack = _flow != _CreateProjectFlow.chooser;
    final title = switch (_flow) {
      _CreateProjectFlow.chooser =>
        loc?.translate('create_project_dialog_title') ?? 'Add Project',
      _CreateProjectFlow.newAi =>
        loc?.translate('create_project_new_project_title') ?? 'New Project',
      _CreateProjectFlow.importLocal =>
        loc?.translate('create_project_import_local_title') ??
            'Import Local Zip',
      _CreateProjectFlow.importPublic =>
        loc?.translate('create_project_import_public_title') ??
            'Import Public Repo',
      _CreateProjectFlow.githubCollaborator =>
        loc?.translate('create_project_github_import_title') ?? 'GitHub Import',
    };
    return CreateProjectDialogShell(
      title: title,
      showBack: showBack,
      isAnyLoading: isAnyLoading,
      onBack: showBack ? _goBackToChooser : null,
      onClose: () => Navigator.of(context).pop(),
      child: _buildFlowContent(),
    );
  }

  void _goBackToChooser() {
    _newProjectWorkspacePollTimer?.cancel();
    _newProjectModelRetryTimer?.cancel();
    setState(() {
      _flow = _CreateProjectFlow.chooser;
      _error = '';
      _ghError = '';
    });
  }

  bool _isAuthError(Object err) {
    final s = err.toString().toLowerCase();
    return s.contains('401') ||
        s.contains('auth') ||
        s.contains('unauthenticated') ||
        s.contains('expired');
  }

  ProjectTemplateInfo _localizedAutoTemplateInfo(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return ProjectTemplateInfo(
      templateRepo: _autoTemplateRepo,
      name: loc?.translate('create_project_template_auto_name') ?? 'Auto',
      description:
          loc?.translate('create_project_template_auto_description') ??
          'Let D1V choose the best template based on your prompt.',
      category: 'system',
      kind: 'smart',
      featured: true,
      rank: -1,
    );
  }

  List<ProjectTemplateInfo> _templateOptions(BuildContext context) {
    return <ProjectTemplateInfo>[
      _localizedAutoTemplateInfo(context),
      ..._availableTemplates.where(
        (template) => template.templateRepo != _autoTemplateRepo,
      ),
    ];
  }

  void _startNewProjectModelBootstrap() {
    _newProjectWorkspacePollTimer?.cancel();
    _newProjectModelRetryTimer?.cancel();
    setState(() {
      _hasLoadedModelConfig = false;
      _isLoadingModels = false;
      _availableModels = <ModelInfo>[];
      _selectedModelId = '';
      _newProjectWorkspacePhase = WorkspacePhase.unknown;
    });

    unawaited(_refreshNewProjectWorkspacePhase(bypassCache: true));
    _newProjectWorkspacePollTimer = Timer.periodic(const Duration(seconds: 3), (
      _,
    ) {
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      unawaited(_refreshNewProjectWorkspacePhase(bypassCache: true));
    });
  }

  Future<void> _refreshNewProjectWorkspacePhase({
    required bool bypassCache,
  }) async {
    if (!mounted || _flow != _CreateProjectFlow.newAi) return;
    try {
      final status = await _workspaceService.getWorkspaceStatus(
        bypassCache: bypassCache,
      );
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      final phase = normalizeWorkspacePhase(status);
      setState(() {
        _newProjectWorkspacePhase = phase;
      });

      if (phase == WorkspacePhase.ready && !_hasLoadedModelConfig) {
        await _loadModelConfigForNewProject();
      }
      if (phase == WorkspacePhase.ready && _hasLoadedModelConfig) {
        _newProjectWorkspacePollTimer?.cancel();
      }
    } catch (_) {
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      setState(() {
        _newProjectWorkspacePhase = WorkspacePhase.error;
      });
    }
  }

  Future<void> _loadModelConfigForNewProject() async {
    if (!mounted || _flow != _CreateProjectFlow.newAi) return;
    if (_isLoadingModels || _hasLoadedModelConfig) return;
    if (_newProjectWorkspacePhase != WorkspacePhase.ready) return;

    setState(() {
      _isLoadingModels = true;
    });

    try {
      final config = await _modelConfigService.getModelConfig(retries: 0);
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      final models = config.availableModels;
      final firstModel = models.isNotEmpty ? models.first.id.trim() : '';
      final normalizedCached =
          (await _modelConfigService.getCachedModel())?.trim() ?? '';
      final modelExists =
          normalizedCached.isNotEmpty &&
          models.any((m) => m.id.trim() == normalizedCached);
      final selected = modelExists ? normalizedCached : firstModel;

      setState(() {
        _availableModels = models;
        _selectedModelId = selected;
        _hasLoadedModelConfig = true;
        _isLoadingModels = false;
      });

      if (selected.isNotEmpty) {
        await _modelConfigService.setCachedModel(selected);
        final apiModel = config.model.trim();
        if (apiModel != selected) {
          try {
            await _modelConfigService.setModelConfig(selected, retries: 0);
          } catch (_) {
            // Non-fatal: still allow project creation.
          }
        }
      }
      _newProjectModelRetryTimer?.cancel();
    } catch (e) {
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      setState(() {
        _isLoadingModels = false;
        _hasLoadedModelConfig = false;
      });
      if (_isAuthError(e)) {
        setState(() {
          _error =
              AppLocalizations.of(
                context,
              )?.translate('create_project_login_expired_models') ??
              'Login expired. Please sign in again before loading models.';
        });
        return;
      }
      _newProjectModelRetryTimer?.cancel();
      _newProjectModelRetryTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || _flow != _CreateProjectFlow.newAi) return;
        if (_newProjectWorkspacePhase != WorkspacePhase.ready) return;
        unawaited(_loadModelConfigForNewProject());
      });
    }
  }

  Future<void> _loadProjectTemplates() async {
    if (!mounted || _flow != _CreateProjectFlow.newAi) return;
    if (_isLoadingTemplates) return;

    setState(() {
      _isLoadingTemplates = true;
    });

    try {
      final templates = await D1vaiService().getProjectTemplates();
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;

      final available = templates
          .where((template) => template.templateRepo.trim().isNotEmpty)
          .toList();
      final hasSelectedTemplate =
          _selectedTemplateRepo == _autoTemplateRepo ||
          available.any(
            (template) => template.templateRepo == _selectedTemplateRepo,
          );

      setState(() {
        _availableTemplates = available;
        _isLoadingTemplates = false;
        if (!hasSelectedTemplate) {
          _selectedTemplateRepo = _autoTemplateRepo;
        }
      });
    } catch (e) {
      if (!mounted || _flow != _CreateProjectFlow.newAi) return;
      setState(() {
        _availableTemplates = const <ProjectTemplateInfo>[];
        _isLoadingTemplates = false;
        if (_isAuthError(e)) {
          _error =
              AppLocalizations.of(
                context,
              )?.translate('create_project_login_expired_templates') ??
              'Login expired. Please sign in again before loading templates.';
        }
      });
    }
  }

  Future<void> _handleModelSelectionChanged(String modelId) async {
    final next = modelId.trim();
    if (next.isEmpty || next == _selectedModelId) return;
    setState(() {
      _selectedModelId = next;
    });
    await _modelConfigService.setCachedModel(next);
  }

  void _handleTemplateSelectionChanged(String templateRepo) {
    final next = templateRepo.trim();
    if (next.isEmpty || next == _selectedTemplateRepo) return;
    setState(() {
      _selectedTemplateRepo = next;
    });
  }

  Widget _buildFlowContent() {
    return switch (_flow) {
      _CreateProjectFlow.chooser => _buildChooser(),
      _CreateProjectFlow.newAi => _buildNewProjectTab(),
      _CreateProjectFlow.importLocal => _buildImportLocalTab(),
      _CreateProjectFlow.importPublic => _buildImportRepoTab(),
      _CreateProjectFlow.githubCollaborator => GithubCollaboratorImportView(
        step: _ghStep,
        loading: _ghLoading,
        errorText: _ghError,
        botUsername: _ghBotUsername,
        invitationAccepted: _ghInvitationAccepted,
        accessVerified: _ghAccessVerified,
        repoInfo: _ghRepoInfo,
        repoUrlController: _ghRepoUrlController,
        projectNameController: _ghProjectNameController,
        onRepoUrlChanged: (_) {
          if (_ghError.isEmpty) return;
          setState(() {
            _ghError = '';
          });
        },
        onCopyBotUsername: _copyGitHubBotUsername,
        onOpenSettings: _handleGithubOpenSettings,
        onAcceptInvitation: _handleGithubAcceptInvitation,
        onVerifyAccess: _handleGithubVerifyAccess,
        onImportProject: _handleGithubImportProject,
      ),
    };
  }

  Future<void> _copyGitHubBotUsername() async {
    await Clipboard.setData(ClipboardData(text: _ghBotUsername));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: AppLocalizations.of(context)?.translate('copied') ?? 'Copied',
      message:
          AppLocalizations.of(
            context,
          )?.translate('create_project_bot_username_copied') ??
          'Bot username copied to clipboard',
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildChooser() {
    final disabled = _isLoading || _ghLoading;
    return CreateProjectChooserView(
      disabled: disabled,
      onChooseNewAi: () {
        setState(() {
          _flow = _CreateProjectFlow.newAi;
          _error = '';
          _selectedTemplateRepo = _autoTemplateRepo;
        });
        unawaited(_loadProjectTemplates());
        _startNewProjectModelBootstrap();
      },
      onChooseImportLocal: () {
        _newProjectWorkspacePollTimer?.cancel();
        _newProjectModelRetryTimer?.cancel();
        setState(() {
          _flow = _CreateProjectFlow.importLocal;
          _error = '';
        });
      },
      onChooseImportPublic: () {
        _newProjectWorkspacePollTimer?.cancel();
        _newProjectModelRetryTimer?.cancel();
        setState(() {
          _flow = _CreateProjectFlow.importPublic;
          _error = '';
        });
      },
      onChooseGithubCollaborator: () {
        _newProjectWorkspacePollTimer?.cancel();
        _newProjectModelRetryTimer?.cancel();
        setState(() {
          _flow = _CreateProjectFlow.githubCollaborator;
          _ghStep = 1;
          _ghInvitationAccepted = false;
          _ghAccessVerified = false;
          _ghRepoInfo = null;
          _ghError = '';
        });
        unawaited(_ensureGitHubBotUsername());
      },
    );
  }

  /// 构建新建项目标签
  Widget _buildNewProjectTab() {
    return _isLoading
        ? const CreateProjectLoadingView()
        : CreateProjectNewAiView(
            descriptionController: _descriptionController,
            errorText: _error.isNotEmpty ? _error : null,
            onChanged: (_) {
              if (_error.isEmpty) return;
              setState(() {
                _error = '';
              });
            },
            onCreate: _handleCreateProject,
            models: _availableModels,
            selectedModelId: _selectedModelId,
            onModelChanged: (modelId) {
              unawaited(_handleModelSelectionChanged(modelId));
            },
            isModelLoading: _isLoadingModels,
            isWorkspaceReady: _newProjectWorkspacePhase == WorkspacePhase.ready,
            templateOptions: _templateOptions(context),
            selectedTemplateRepo: _selectedTemplateRepo,
            onTemplateChanged: _handleTemplateSelectionChanged,
            isTemplateLoading: _isLoadingTemplates,
          );
  }

  /// 构建导入仓库标签
  Widget _buildImportRepoTab() {
    return _isLoading
        ? const CreateProjectLoadingView()
        : CreateProjectImportPublicView(
            urlController: _urlController,
            nameController: _nameController,
            descriptionController: _repoNameController,
            errorText: _error.isNotEmpty ? _error : null,
            onChanged: (_) {
              if (_error.isEmpty) return;
              setState(() {
                _error = '';
              });
            },
            onImport: _handleImportRepo,
          );
  }

  Widget _buildImportLocalTab() {
    return _isLoading
        ? const CreateProjectLoadingView()
        : CreateProjectImportLocalView(
            nameController: _localProjectNameController,
            descriptionController: _localProjectDescriptionController,
            archiveFileName: _localArchiveFileName,
            isPrivate: _localImportPrivate,
            errorText: _error.isNotEmpty ? _error : null,
            onChanged: (_) {
              if (_error.isEmpty) return;
              setState(() {
                _error = '';
              });
            },
            onPickArchive: _pickLocalArchive,
            onPrivateChanged: (value) {
              setState(() {
                _localImportPrivate = value;
              });
            },
            onImport: _handleImportLocal,
          );
  }

  /// 处理创建项目
  Future<void> _handleCreateProject() async {
    if (_isLoading) return;
    final description = _descriptionController.text.trim();

    // Validate: description must be at least 8 characters (match d1vai frontend)
    if (description.isEmpty) {
      setState(() {
        _error =
            AppLocalizations.of(
              context,
            )?.translate('create_project_description_required') ??
            'Please describe what you want to build';
      });
      return;
    }

    if (description.length < 8) {
      setState(() {
        _error =
            AppLocalizations.of(
              context,
            )?.translate('create_project_description_too_short') ??
            'Description is too short. Please provide more details (min 8 chars)';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = (prefs.getString('auth_token') ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _error =
            AppLocalizations.of(
              context,
            )?.translate('create_project_token_missing') ??
            'Not logged in or token missing. Please login again.\n\nTip: Settings → Profile → API → Copy diagnostics.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final selectedModel = _selectedModelId.trim();
      if (selectedModel.isNotEmpty) {
        try {
          await _modelConfigService.setModelConfig(selectedModel, retries: 0);
          await _modelConfigService.setCachedModel(selectedModel);
        } catch (e) {
          if (mounted) {
            SnackBarHelper.showInfo(
              context,
              title:
                  AppLocalizations.of(
                    context,
                  )?.translate('model_switch_title') ??
                  'Model',
              message:
                  (AppLocalizations.of(context)?.translate(
                            'create_project_model_switch_failed_continue',
                          ) ??
                          'Failed to switch model, continuing with server default. ({error})')
                      .replaceAll('{error}', '$e'),
              duration: const Duration(seconds: 3),
            );
          }
        }
      }

      // Align with d1vai web: warm up workspace before project creation to avoid
      // opcode-manager failures on cold/archived workspaces.
      try {
        await _workspaceService.ensureWorkspaceReady();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error =
              (AppLocalizations.of(
                        context,
                      )?.translate('create_project_workspace_not_ready') ??
                      'Workspace is not ready: {error}\n\nAPI Base: {base}')
                  .replaceAll('{error}', '$e')
                  .replaceAll('{base}', ApiClient.baseUrl);
        });
        return;
      }

      final d1vaiService = D1vaiService();

      // Match d1vai frontend implementation
      final result = await d1vaiService.createProjectWithIntegrations(
        prompt: description,
        maxDescLen: 120,
        templateRepo: _selectedTemplateRepo,
        enablePay: false,
        enableDatabase: true,
      );

      if (!mounted) return;

      final project = result['project'] as Map<String, dynamic>?;
      final projectId = project?['id'] as String?;

      if (projectId == null) {
        throw Exception(
          AppLocalizations.of(
                context,
              )?.translate('create_project_failed_get_project_id') ??
              'Failed to get project ID',
        );
      }

      if (!mounted) return;

      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      await projectProvider.refresh();

      if (!mounted) return;

      final router = GoRouter.of(context);
      Navigator.pop(context);

      // Match d1vai frontend autoprompt generation
      final followup =
          'Plan mvp version to replace the hello word page functionality and complete it in multiple steps. Finally, you need to check for syntax errors and fix the known issues found.thinkhard';
      final autoprompt = '$description\n\n$followup';

      // Jump to chat page with autoprompt
      router.push(
        '/projects/$projectId/chat?autoprompt=${Uri.encodeQueryComponent(autoprompt)}',
      );
    } catch (e) {
      if (isInsufficientBalanceError(e)) {
        if (mounted) {
          await showInsufficientBalanceDialog(context);
          setState(() {
            _isLoading = false;
            _error = '';
          });
        }
        return;
      }

      var errText = e.toString();
      final mayBeOpcodeIssue =
          errText.contains('opcode-manager') ||
          errText.contains('internal_server_error') ||
          errText.contains('HTTP Error: 500');

      if (mayBeOpcodeIssue) {
        try {
          if (!mounted) return;
          SnackBarHelper.showInfo(
            context,
            title:
                AppLocalizations.of(context)?.translate('retry') ?? 'Retrying',
            message:
                AppLocalizations.of(
                  context,
                )?.translate('create_project_retry_create_integrations') ??
                'Create-with-integrations failed, retrying once…',
            duration: const Duration(seconds: 5),
          );

          await _workspaceService.ensureWorkspaceReady();

          final d1vaiService = D1vaiService();
          final retryResult = await d1vaiService.createProjectWithIntegrations(
            prompt: description,
            maxDescLen: 120,
            templateRepo: _selectedTemplateRepo,
            enablePay: false,
            enableDatabase: true,
          );

          if (!mounted) return;

          final project = retryResult['project'] as Map<String, dynamic>?;
          final projectId = project?['id']?.toString();
          if (projectId == null || projectId.isEmpty) {
            throw Exception(
              AppLocalizations.of(
                    context,
                  )?.translate('create_project_retry_missing_id') ??
                  'Retry create project missing id',
            );
          }

          final projectProvider = Provider.of<ProjectProvider>(
            context,
            listen: false,
          );
          await projectProvider.refresh();

          if (!mounted) return;

          final router = GoRouter.of(context);
          Navigator.pop(context);

          final followup =
              'Plan mvp version to replace the hello word page functionality and complete it in multiple steps. Finally, you need to check for syntax errors and fix the known issues found.thinkhard';
          final autoprompt = '$description\n\n$followup';

          router.push(
            '/projects/$projectId/chat?autoprompt=${Uri.encodeQueryComponent(autoprompt)}',
          );
          return;
        } catch (retryErr) {
          if (isInsufficientBalanceError(retryErr)) {
            if (mounted) {
              await showInsufficientBalanceDialog(context);
              setState(() {
                _isLoading = false;
                _error = '';
              });
            }
            return;
          }
          // fallthrough to show combined error below
          errText = 'primary=$errText; retry=$retryErr';
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_failed_to_create') ??
                    'Failed to create project: {error}\n\nAPI Base: {base}')
                .replaceAll('{error}', errText)
                .replaceAll('{base}', ApiClient.baseUrl);
      });
    }
  }

  /// 处理导入仓库
  Future<void> _handleImportRepo() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();

    if (url.isEmpty || name.isEmpty) {
      setState(() {
        _error =
            AppLocalizations.of(
              context,
            )?.translate('create_project_fill_required') ??
            'Please fill in all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final d1vaiService = D1vaiService();

      // 使用真实 API 导入仓库
      final result = await d1vaiService.importPublicRepoToOrg({
        'source_url': url,
        'project_name': name,
        'project_description': _repoNameController.text.trim().isEmpty
            ? null
            : _repoNameController.text.trim(),
        'private': true,
      });

      if (!mounted) return;

      final project = (result is Map<String, dynamic>)
          ? (result['project'] as Map<String, dynamic>?)
          : null;
      final projectId = project?['id']?.toString();
      if (projectId == null || projectId.isEmpty) {
        throw Exception(
          AppLocalizations.of(
                context,
              )?.translate('create_project_failed_get_project_id') ??
              'Failed to get project ID',
        );
      }

      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      await projectProvider.refresh();

      if (!mounted) return;

      Navigator.pop(context);

      if (!mounted) return;

      // 跳转到项目 chat（对齐“创建成功后进入 chat”）
      GoRouter.of(context).push('/projects/$projectId/chat?tab=preview');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_failed_import_repo') ??
                    'Failed to import repository: {error}')
                .replaceAll('{error}', '$e');
      });
    }
  }

  Future<void> _pickLocalArchive() async {
    final loc = AppLocalizations.of(context);
    final selectedArchiveEmptyText =
        loc?.translate('create_project_selected_archive_empty') ??
        'Selected archive is empty';
    final failedChooseArchiveText =
        loc?.translate('create_project_failed_choose_archive') ??
        'Failed to choose archive: {error}';

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null) return;

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && file.path!.trim().isNotEmpty) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw Exception(selectedArchiveEmptyText);
      }

      if (!mounted) return;
      setState(() {
        _localArchiveBytes = bytes;
        _localArchiveFileName = file.name;
        if (_localProjectNameController.text.trim().isEmpty) {
          final normalized = file.name.replaceAll(
            RegExp(r'\.zip$', caseSensitive: false),
            '',
          );
          _localProjectNameController.text = normalized;
        }
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = failedChooseArchiveText.replaceAll('{error}', '$e');
      });
    }
  }

  Future<void> _handleImportLocal() async {
    final projectName = _localProjectNameController.text.trim();
    final archiveBytes = _localArchiveBytes;
    final archiveFileName = (_localArchiveFileName ?? '').trim();

    if (projectName.isEmpty ||
        archiveBytes == null ||
        archiveFileName.isEmpty) {
      setState(() {
        _error =
            AppLocalizations.of(
              context,
            )?.translate('create_project_choose_zip_and_name') ??
            'Please choose a zip archive and fill in the project name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final d1vaiService = D1vaiService();
      final result = await d1vaiService.importProjectFromLocal(
        archiveBytes: archiveBytes,
        archiveFileName: archiveFileName,
        projectName: projectName,
        projectDescription: _localProjectDescriptionController.text.trim(),
        isPrivate: _localImportPrivate,
      );

      if (!mounted) return;

      final nested = result['data'];
      final payload = nested is Map<String, dynamic>
          ? nested
          : nested is Map
          ? nested.cast<String, dynamic>()
          : result;
      final project = payload['project'] is Map<String, dynamic>
          ? payload['project'] as Map<String, dynamic>
          : payload['project'] is Map
          ? (payload['project'] as Map).cast<String, dynamic>()
          : payload;
      final projectId =
          project['id']?.toString() ??
          payload['project_id']?.toString() ??
          payload['id']?.toString();
      if (projectId == null || projectId.isEmpty) {
        throw Exception(
          AppLocalizations.of(
                context,
              )?.translate('create_project_failed_get_project_id') ??
              'Failed to get project ID',
        );
      }

      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      await projectProvider.refresh();

      if (!mounted) return;
      Navigator.pop(context);
      if (!mounted) return;
      GoRouter.of(context).push('/projects/$projectId/chat?tab=preview');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_failed_import_local') ??
                    'Failed to import local zip: {error}')
                .replaceAll('{error}', '$e');
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  // ===========================================================================
  // GitHub collaborator import (align with d1vai web QuickImportSetup)
  // ===========================================================================

  Future<void> _ensureGitHubBotUsername() async {
    try {
      final d1vaiService = D1vaiService();
      final res = await d1vaiService.getGitHubBotUsername();
      final username = res['username']?.toString();
      if (!mounted) return;
      if (username != null && username.isNotEmpty) {
        setState(() {
          _ghBotUsername = username;
        });
      }
    } catch (_) {
      // Best-effort; keep default.
    }
  }

  Future<void> _handleGithubOpenSettings() async {
    final repoUrl = _ghRepoUrlController.text.trim();
    final repoFullName = parseGithubRepoFullName(repoUrl);
    if (repoFullName == null) {
      setState(() {
        _ghError =
            AppLocalizations.of(
              context,
            )?.translate('create_project_invalid_repo_url') ??
            'Invalid repo URL. Example: https://github.com/owner/repo';
      });
      return;
    }

    await _ensureGitHubBotUsername();
    if (!mounted) return;

    final parts = repoFullName.split('/');
    final owner = parts[0];
    final repo = parts[1];
    final settingsUrl = Uri.parse(
      'https://github.com/$owner/$repo/settings/access',
    );

    setState(() {
      _ghStep = 2;
      _ghInvitationAccepted = false;
      _ghAccessVerified = false;
      _ghRepoInfo = null;
      _ghProjectNameController.text = repo;
      _ghError = '';
    });

    final ok = await launchUrl(
      settingsUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      SnackBarHelper.showError(
        context,
        title:
            AppLocalizations.of(context)?.translate('docs_open_failed_title') ??
            'Open failed',
        message:
            AppLocalizations.of(
              context,
            )?.translate('create_project_could_not_open_github_settings') ??
            'Could not open GitHub settings in browser',
      );
    }
  }

  Future<void> _handleGithubAcceptInvitation() async {
    final repoFullName = parseGithubRepoFullName(
      _ghRepoUrlController.text.trim(),
    );
    if (repoFullName == null) {
      setState(() {
        _ghError =
            AppLocalizations.of(
              context,
            )?.translate('create_project_invalid_repo_url_simple') ??
            'Invalid repo URL';
      });
      return;
    }

    setState(() {
      _ghLoading = true;
      _ghError = '';
    });

    try {
      final d1vaiService = D1vaiService();
      await d1vaiService.acceptGitHubInvitation(repoFullName);
      if (!mounted) return;
      setState(() {
        _ghInvitationAccepted = true;
        _ghStep = 3;
      });
      SnackBarHelper.showSuccess(
        context,
        title:
            AppLocalizations.of(context)?.translate('invitation') ??
            'Invitation',
        message:
            AppLocalizations.of(
              context,
            )?.translate('create_project_invitation_accepted_message') ??
            'Invitation accepted',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghError =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_accept_invitation_failed') ??
                    'Accept invitation failed: {error}')
                .replaceAll('{error}', '$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _ghLoading = false;
        });
      }
    }
  }

  Future<void> _handleGithubVerifyAccess() async {
    final repoFullName = parseGithubRepoFullName(
      _ghRepoUrlController.text.trim(),
    );
    if (repoFullName == null) {
      setState(() {
        _ghError =
            AppLocalizations.of(
              context,
            )?.translate('create_project_invalid_repo_url_simple') ??
            'Invalid repo URL';
      });
      return;
    }
    final parts = repoFullName.split('/');
    final owner = parts[0];
    final repo = parts[1];

    setState(() {
      _ghLoading = true;
      _ghError = '';
    });
    try {
      final d1vaiService = D1vaiService();
      final res = await d1vaiService.checkRepositoryAccess(owner, repo);
      if (!mounted) return;
      setState(() {
        _ghRepoInfo = res;
        _ghAccessVerified = true;
        if (_ghProjectNameController.text.trim().isEmpty) {
          _ghProjectNameController.text = (res['repository_name'] ?? repo)
              .toString();
        }
      });
      SnackBarHelper.showSuccess(
        context,
        title: AppLocalizations.of(context)?.translate('access') ?? 'Access',
        message:
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_access_verified_for') ??
                    'Access verified for {repo}')
                .replaceAll('{repo}', repoFullName),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghAccessVerified = false;
        _ghRepoInfo = null;
        _ghError =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_verify_access_failed') ??
                    'Verify access failed: {error}')
                .replaceAll('{error}', '$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _ghLoading = false;
        });
      }
    }
  }

  Future<void> _handleGithubImportProject() async {
    final repoFullName = parseGithubRepoFullName(
      _ghRepoUrlController.text.trim(),
    );
    final repoInfo = _ghRepoInfo;
    if (repoFullName == null || repoInfo == null) return;

    final projectName = _ghProjectNameController.text.trim().isNotEmpty
        ? _ghProjectNameController.text.trim()
        : (repoInfo['repository_name']?.toString() ??
              repoFullName.split('/')[1]);

    final importedDescription =
        (AppLocalizations.of(
                  context,
                )?.translate('create_project_imported_from_github') ??
                'Imported from GitHub: {repo}')
            .replaceAll('{repo}', repoFullName);

    final payload = <String, dynamic>{
      'repository_full_name': repoFullName,
      'project_name': projectName,
      'project_description':
          (repoInfo['description']?.toString().isNotEmpty ?? false)
          ? repoInfo['description'].toString()
          : importedDescription,
      'repository_url': repoInfo['clone_url'],
      'repository_ssh_url': repoInfo['ssh_url'],
      'default_branch': repoInfo['default_branch'] ?? 'main',
      'is_private': repoInfo['is_private'] ?? false,
      'primary_language': repoInfo['language'],
    };

    setState(() {
      _ghLoading = true;
      _ghError = '';
    });

    try {
      final d1vaiService = D1vaiService();
      final res = await d1vaiService.importProjectFromGithub(payload);
      if (!mounted) return;

      final normalized = normalizeImportedProject(res);
      final projectId = normalized.projectId;
      if (projectId == null || projectId.isEmpty) {
        throw Exception(
          AppLocalizations.of(
                context,
              )?.translate('create_project_missing_project_id_after_import') ??
              'Import succeeded but missing project id',
        );
      }

      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      await projectProvider.refresh();

      if (!mounted) return;
      Navigator.pop(context);
      GoRouter.of(context).push('/projects/$projectId/chat?tab=preview');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghError =
            (AppLocalizations.of(
                      context,
                    )?.translate('create_project_failed_import_project') ??
                    'Import failed: {error}')
                .replaceAll('{error}', '$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _ghLoading = false;
        });
      }
    }
  }
}

enum _CreateProjectFlow {
  chooser,
  newAi,
  importLocal,
  importPublic,
  githubCollaborator,
}
