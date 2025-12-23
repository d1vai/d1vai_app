import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../services/d1vai_service.dart';
import 'button.dart';
import 'input.dart';
import 'progress_widget.dart';
import 'snackbar_helper.dart';

/// 项目创建对话框
class CreateProjectDialog extends StatefulWidget {
  final Widget? trigger;
  final Function(UserProject)? onCreated;

  const CreateProjectDialog({super.key, this.trigger, this.onCreated});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();

  _CreateProjectFlow _flow = _CreateProjectFlow.chooser;
  bool _isLoading = false;
  String _error = '';

  // GitHub collaborator import state (align with d1vai web QuickImportSetup)
  int _ghStep = 1; // 1..3
  String _ghBotUsername = 'd1v-dev';
  bool _ghLoading = false;
  String _ghError = '';
  bool _ghInvitationAccepted = false;
  bool _ghAccessVerified = false;
  Map<String, dynamic>? _ghRepoInfo;
  final TextEditingController _ghRepoUrlController = TextEditingController();
  final TextEditingController _ghProjectNameController =
      TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _repoNameController.dispose();
    _ghRepoUrlController.dispose();
    _ghProjectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isAnyLoading = _isLoading || _ghLoading;
    final showBack = _flow != _CreateProjectFlow.chooser;
    final title = switch (_flow) {
      _CreateProjectFlow.chooser => 'Add Project',
      _CreateProjectFlow.newAi => 'New Project',
      _CreateProjectFlow.importPublic => 'Import Public Repo',
      _CreateProjectFlow.githubCollaborator => 'GitHub Import',
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.9, // 90% of screen height max
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: isAnyLoading ? null : _goBackToChooser,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    )
                  else
                    Icon(
                      Icons.add_circle_outline,
                      color: theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isAnyLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 内容区域 - 可滚动，动态高度
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_flow) {
                      _CreateProjectFlow.chooser => _buildChooser(),
                      _CreateProjectFlow.newAi => _buildNewProjectTab(),
                      _CreateProjectFlow.importPublic => _buildImportRepoTab(),
                      _CreateProjectFlow.githubCollaborator =>
                        _buildGithubImportTab(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBackToChooser() {
    setState(() {
      _flow = _CreateProjectFlow.chooser;
      _error = '';
      _ghError = '';
    });
  }

  Widget _buildChooser() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('chooser'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how you want to start',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        _OptionCard(
          icon: Icons.auto_awesome,
          title: 'New project (AI)',
          subtitle: 'Describe what you want to build and we set up everything.',
          badgeText: 'Recommended',
          badgeColor: theme.colorScheme.primary,
          onTap: _isLoading || _ghLoading
              ? null
              : () {
                  setState(() {
                    _flow = _CreateProjectFlow.newAi;
                    _error = '';
                  });
                },
        ),
        const SizedBox(height: 10),
        _OptionCard(
          icon: Icons.public,
          title: 'Import public repo',
          subtitle: 'Mirror a public GitHub repo into the org workspace.',
          onTap: _isLoading || _ghLoading
              ? null
              : () {
                  setState(() {
                    _flow = _CreateProjectFlow.importPublic;
                    _error = '';
                  });
                },
        ),
        const SizedBox(height: 10),
        _OptionCard(
          icon: Icons.hub,
          title: 'Import from GitHub (collaborator)',
          subtitle:
              'Guided import: add bot → accept invite → verify access → import.',
          onTap: _isLoading || _ghLoading
              ? null
              : () {
                  setState(() {
                    _flow = _CreateProjectFlow.githubCollaborator;
                    _ghStep = 1;
                    _ghInvitationAccepted = false;
                    _ghAccessVerified = false;
                    _ghRepoInfo = null;
                    _ghError = '';
                  });
                  _ensureGitHubBotUsername();
                },
        ),
      ],
    );
  }

  /// 构建新建项目标签
  Widget _buildNewProjectTab() {
    final theme = Theme.of(context);
    return _isLoading
        ? _buildLoadingState()
        : Column(
            key: const ValueKey('new_ai'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Describe what you want to build. We will create the project and continue in chat.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Input(
                controller: _descriptionController,
                onChanged: (value) {
                  setState(() {
                    // Clear error when user starts typing
                    if (value.trim().isNotEmpty && _error.isNotEmpty) {
                      _error = '';
                    }
                  });
                },
                labelText: 'Project Description',
                hintText: 'Describe your app or website in detail...',
                variant: InputVariant.outlined,
                maxLines: 4,
                errorText: _error.isNotEmpty ? _error : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: include pages, auth, database, and key workflows. (min 8 chars)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  onPressed:
                      _descriptionController.text.trim().isEmpty ||
                          _descriptionController.text.trim().length < 8
                      ? null
                      : _handleCreateProject,
                  disabled:
                      _descriptionController.text.trim().isEmpty ||
                      _descriptionController.text.trim().length < 8,
                  variant: ButtonVariant.defaultVariant,
                  size: ButtonSize.defaultSize,
                  text: 'Create Project',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
  }

  /// 构建导入仓库标签
  Widget _buildImportRepoTab() {
    final theme = Theme.of(context);
    return _isLoading
        ? _buildLoadingState()
        : Column(
            key: const ValueKey('import_public'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.public, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'We will mirror the public repo into the organization workspace. Large repos may take longer.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Input(
                controller: _urlController,
                onChanged: (value) {
                  setState(() {});
                },
                labelText: 'Public Repo URL',
                hintText: 'https://github.com/owner/repo',
                variant: InputVariant.outlined,
                prefixIcon: const Icon(Icons.link),
              ),
              const SizedBox(height: 8),
              Text(
                'Example: https://github.com/owner/repo',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 16),
              Input(
                controller: _nameController,
                onChanged: (value) {
                  setState(() {});
                },
                labelText: 'Project Name',
                hintText: 'my-project',
                variant: InputVariant.outlined,
                prefixIcon: const Icon(Icons.folder),
              ),
              const SizedBox(height: 16),
              Input(
                controller: _repoNameController,
                onChanged: (value) {
                  setState(() {});
                },
                labelText: 'Description',
                hintText: 'Optional description',
                variant: InputVariant.outlined,
                prefixIcon: const Icon(Icons.description),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Button(
                  onPressed:
                      _urlController.text.trim().isEmpty ||
                          _nameController.text.trim().isEmpty
                      ? null
                      : _handleImportRepo,
                  disabled:
                      _urlController.text.trim().isEmpty ||
                      _nameController.text.trim().isEmpty,
                  variant: ButtonVariant.defaultVariant,
                  size: ButtonSize.defaultSize,
                  text: 'Import Repository',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressWidget(
          tipList: const [
            'Planning project structure...',
            'Setting up integrations...',
            'Finalizing setup...',
          ],
          completed: false,
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        Text(
          'Creating your project. This may take a few seconds...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 处理创建项目
  Future<void> _handleCreateProject() async {
    if (_isLoading) return;
    final description = _descriptionController.text.trim();

    // Validate: description must be at least 8 characters (match d1vai frontend)
    if (description.isEmpty) {
      setState(() {
        _error = 'Please describe what you want to build';
      });
      return;
    }

    if (description.length < 8) {
      setState(() {
        _error =
            'Description is too short. Please provide more details (min 8 chars)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final d1vaiService = D1vaiService();

      // Match d1vai frontend implementation
      final result = await d1vaiService.createProjectWithIntegrations(
        prompt: description,
        maxDescLen: 120,
        enablePay: false,
        enableDatabase: true,
      );

      if (!mounted) return;

      final project = result['project'] as Map<String, dynamic>?;
      final projectId = project?['id'] as String?;

      if (projectId == null) {
        throw Exception('Failed to get project ID');
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
      setState(() {
        _isLoading = false;
        _error = 'Failed to create project: $e';
      });
    }
  }

  /// 处理导入仓库
  Future<void> _handleImportRepo() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();

    if (url.isEmpty || name.isEmpty) {
      setState(() {
        _error = 'Please fill in all required fields';
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
        throw Exception('Failed to get project ID');
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
      setState(() {
        _isLoading = false;
        _error = 'Failed to import repository: $e';
      });
    }
  }

  // ===========================================================================
  // GitHub collaborator import (align with d1vai web QuickImportSetup)
  // ===========================================================================

  Widget _buildGithubImportTab() {
    final theme = Theme.of(context);
    return _ghLoading
        ? _buildLoadingState()
        : Column(
            key: const ValueKey('github_collab'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hub, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guided collaborator import: add bot → accept invite → verify access → import.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Progress (1..3)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Step $_ghStep of 3',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    _ghStep == 1
                        ? 'Connect repo'
                        : _ghStep == 2
                        ? 'Add collaborator'
                        : 'Import project',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _ghStep / 3.0,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),

              if (_ghError.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.error),
                  ),
                  child: Text(
                    _ghError,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _ghStep == 1
                  ? _buildGithubStep1(theme)
                  : _ghStep == 2
                  ? _buildGithubStep2(theme)
                  : _buildGithubStep3(theme),
            ],
          );
  }

  Widget _buildGithubStep1(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Input(
          controller: _ghRepoUrlController,
          onChanged: (v) {
            setState(() {
              _ghError = '';
            });
          },
          labelText: 'Repository URL',
          hintText: 'https://github.com/owner/repo',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.link),
          errorText: _ghError.isNotEmpty ? _ghError : null,
        ),
        const SizedBox(height: 12),
        _buildBotUsernameCard(theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: _ghRepoUrlController.text.trim().isEmpty
                    ? null
                    : _handleGithubOpenSettings,
                disabled: _ghRepoUrlController.text.trim().isEmpty,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text: 'Open GitHub Settings',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGithubStep2(ThemeData theme) {
    final repoFullName = _parseRepoFullName(_ghRepoUrlController.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add "$_ghBotUsername" as a collaborator in GitHub repo settings, then tap “Accept Invitation”.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _buildBotUsernameCard(theme),
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
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: _handleGithubAcceptInvitation,
                disabled: false,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text: _ghInvitationAccepted
                    ? 'Invitation Accepted'
                    : 'Accept Invitation',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGithubStep3(ThemeData theme) {
    final repoFullName = _parseRepoFullName(_ghRepoUrlController.text.trim());
    final repoInfo = _ghRepoInfo;
    final canImport =
        repoFullName != null && repoInfo != null && _ghAccessVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: _handleGithubVerifyAccess,
                disabled: false,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text: _ghAccessVerified ? 'Access Verified' : 'Verify Access',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
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
                  (repoInfo['repository_full_name'] ??
                              repoInfo['repository_name'] ??
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
                  (repoInfo['description'] ?? '').toString(),
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
          controller: _ghProjectNameController,
          labelText: 'Project Name',
          hintText: 'Default: repository name',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.folder),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: canImport ? _handleGithubImportProject : null,
                disabled: !canImport,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text: 'Import Project',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotUsernameCard(ThemeData theme) {
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
                const Text(
                  'GitHub Bot Username',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _ghBotUsername,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _ghBotUsername));
              if (!mounted) return;
              SnackBarHelper.showSuccess(
                context,
                title: 'Copied',
                message: 'Bot username copied to clipboard',
                duration: const Duration(seconds: 2),
              );
            },
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Future<void> _ensureGitHubBotUsername() async {
    try {
      final d1vaiService = D1vaiService();
      final res = await d1vaiService.getGitHubBotUsername();
      final username = res['username']?.toString();
      if (username != null && username.isNotEmpty) {
        setState(() {
          _ghBotUsername = username;
        });
      }
    } catch (_) {
      // Best-effort; keep default.
    }
  }

  String? _parseRepoFullName(String repoUrl) {
    if (repoUrl.trim().isEmpty) return null;
    final match = RegExp(
      r'github\.com\/([^\/]+)\/([^\/\?#]+)',
    ).firstMatch(repoUrl);
    if (match == null) return null;
    final owner = match.group(1);
    final repo = (match.group(2) ?? '').replaceAll(RegExp(r'\.git$'), '');
    if (owner == null || owner.isEmpty || repo.isEmpty) return null;
    return '$owner/$repo';
  }

  Future<void> _handleGithubOpenSettings() async {
    final repoUrl = _ghRepoUrlController.text.trim();
    final repoFullName = _parseRepoFullName(repoUrl);
    if (repoFullName == null) {
      setState(() {
        _ghError = 'Invalid repo URL. Example: https://github.com/owner/repo';
      });
      return;
    }

    await _ensureGitHubBotUsername();

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
        title: 'Open failed',
        message: 'Could not open GitHub settings in browser',
      );
    }
  }

  Future<void> _handleGithubAcceptInvitation() async {
    final repoFullName = _parseRepoFullName(_ghRepoUrlController.text.trim());
    if (repoFullName == null) {
      setState(() {
        _ghError = 'Invalid repo URL';
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
        title: 'Invitation',
        message: 'Invitation accepted',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghError = 'Accept invitation failed: $e';
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
    final repoFullName = _parseRepoFullName(_ghRepoUrlController.text.trim());
    if (repoFullName == null) {
      setState(() {
        _ghError = 'Invalid repo URL';
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
        title: 'Access',
        message: 'Access verified for $repoFullName',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ghAccessVerified = false;
        _ghRepoInfo = null;
        _ghError = 'Verify access failed: $e';
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
    final repoFullName = _parseRepoFullName(_ghRepoUrlController.text.trim());
    final repoInfo = _ghRepoInfo;
    if (repoFullName == null || repoInfo == null) return;

    final projectName = _ghProjectNameController.text.trim().isNotEmpty
        ? _ghProjectNameController.text.trim()
        : (repoInfo['repository_name']?.toString() ??
              repoFullName.split('/')[1]);

    final payload = <String, dynamic>{
      'repository_full_name': repoFullName,
      'project_name': projectName,
      'project_description':
          (repoInfo['description']?.toString().isNotEmpty ?? false)
          ? repoInfo['description'].toString()
          : 'Imported from GitHub: $repoFullName',
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

      final normalized = _normalizeImportedProject(res);
      final projectId = normalized.projectId;
      if (projectId == null || projectId.isEmpty) {
        throw Exception('Import succeeded but missing project id');
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
        _ghError = 'Import failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _ghLoading = false;
        });
      }
    }
  }

  _ImportedProject _normalizeImportedProject(dynamic resp) {
    // Mirrors web normalizeImportedProjectFromResponse:
    // data may be `{ project: {...} }` or `project` directly.
    Map<String, dynamic>? asMap;
    if (resp is Map<String, dynamic>) {
      asMap = resp;
    }
    final data = asMap;
    final project = (data != null && data['project'] is Map<String, dynamic>)
        ? (data['project'] as Map<String, dynamic>)
        : data;
    final idRaw =
        project?['id'] ??
        data?['id'] ??
        data?['project_id'] ??
        data?['projectId'] ??
        project?['project_id'] ??
        project?['projectId'];
    final projectId = idRaw?.toString();
    return _ImportedProject(project: project, projectId: projectId);
  }
}

class _ImportedProject {
  final Map<String, dynamic>? project;
  final String? projectId;
  const _ImportedProject({required this.project, required this.projectId});
}

enum _CreateProjectFlow { chooser, newAi, importPublic, githubCollaborator }

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badgeText;
  final Color? badgeColor;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: enabled ? 1 : 0.5,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? theme.colorScheme.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: (badgeColor ?? theme.colorScheme.primary)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    (badgeColor ?? theme.colorScheme.primary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
