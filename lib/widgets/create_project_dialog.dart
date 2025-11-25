import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../services/d1vai_service.dart';
import 'button.dart';
import 'input.dart';
import 'alert.dart';
import 'progress_widget.dart';

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

  int _activeTab = 0;
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _descriptionController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _repoNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

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
                  Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Project',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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

              // Tab Navigation
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(0, 'New Project'),
                    ),
                    Expanded(
                      child: _buildTabButton(1, 'Import Repo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 内容区域 - 可滚动，动态高度
              Flexible(
                child: SingleChildScrollView(
                  child: _activeTab == 0
                      ? _buildNewProjectTab()
                      : _buildImportRepoTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签按钮
  Widget _buildTabButton(int index, String label) {
    final isActive = _activeTab == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isActive
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建新建项目标签
  Widget _buildNewProjectTab() {
    final theme = Theme.of(context);
    return _isLoading
        ? _buildLoadingState()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Describe your project',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tell us what you want to build. The AI will create the project and generate everything else.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              Input(
                value: _descriptionController.text,
                onChanged: (value) {
                  _descriptionController.text = value;
                  if (value.trim().isNotEmpty && _error.isNotEmpty) {
                    setState(() {
                      _error = '';
                    });
                  }
                },
                labelText: 'Project Description',
                hintText: 'Describe your app or website in detail...',
                variant: InputVariant.outlined,
                maxLines: 4,
                errorText: _error.isNotEmpty ? _error : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  onPressed: _descriptionController.text.trim().isEmpty ||
                          _descriptionController.text.trim().length < 8
                      ? null
                      : _handleCreateProject,
                  disabled: _descriptionController.text.trim().isEmpty ||
                      _descriptionController.text.trim().length < 8,
                  variant: ButtonVariant.defaultVariant,
                  size: ButtonSize.defaultSize,
                  text: 'Create Project',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Import Public Repository',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Clone and mirror a public GitHub repository into the organization',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Input(
                value: _urlController.text,
                onChanged: (value) {
                  _urlController.text = value;
                },
                labelText: 'Public Repo URL',
                hintText: 'https://github.com/owner/repo',
                variant: InputVariant.outlined,
                prefixIcon: const Icon(Icons.link),
              ),
              const SizedBox(height: 16),
              Input(
                value: _nameController.text,
                onChanged: (value) {
                  _nameController.text = value;
                },
                labelText: 'Project Name',
                hintText: 'my-project',
                variant: InputVariant.outlined,
                prefixIcon: const Icon(Icons.folder),
              ),
              const SizedBox(height: 16),
              Input(
                value: _repoNameController.text,
                onChanged: (value) {
                  _repoNameController.text = value;
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
                  disabled: _urlController.text.trim().isEmpty ||
                      _nameController.text.trim().isEmpty,
                  variant: ButtonVariant.defaultVariant,
                  size: ButtonSize.defaultSize,
                  text: 'Import Repository',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        _error = 'Description is too short. Please provide more details (min 8 chars)';
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
      final followup = 'Plan mvp version to replace the hello word page functionality and complete it in multiple steps. Finally, you need to check for syntax errors and fix the known issues found.';
      final autoprompt = '$description\n\n$followup';

      // Jump to chat page with autoprompt
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        router.push('/projects/$projectId/chat?autoprompt=${Uri.encodeQueryComponent(autoprompt)}');
      });
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
      await d1vaiService.importPublicRepoToOrg({
        'source_url': url,
        'project_name': name,
        'project_description': _repoNameController.text.trim().isEmpty
            ? null
            : _repoNameController.text.trim(),
        'private': true,
      });

      if (!mounted) return;

      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      await projectProvider.refresh();

      if (!mounted) return;

      Navigator.pop(context);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Alert(
          child: AlertDescription(
            text: 'Repository imported successfully!',
          ),
        ),
      );

      // 跳转到项目列表
      if (!mounted) return;
      context.push('/projects');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to import repository: $e';
      });
    }
  }
}
