import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../services/d1vai_service.dart';
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
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  int _activeTab = 0;
  bool _isLoading = false;
  String _error = '';
  String _selectedEmoji = '🚀';
  bool _enableDatabase = false;
  bool _enablePayment = false;
  bool _isGeneratingName = false;
  List<String> _tags = [];

  // Validation states
  String? _projectNameError;
  String? _descriptionError;
  String? _tagError;

  final List<String> _popularEmojis = [
    '🚀', '💡', '🎯', '📱', '🌐', '⚡', '🎨', '🔧',
    '💻', '📊', '🛒', '🎮', '📝', '🔐', '🗄️', '📡',
    '🤖', '📚', '🎬', '🎵', '🏠', '🏪', '💰', '📈',
    '🎓', '🏥', '🚗', '✈️', '🎉', '💡', '🔥', '⭐',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _repoNameController.dispose();
    _projectNameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Project',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab 导航
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton(0, 'New Project')),
                  Expanded(child: _buildTabButton(1, 'Import Repo')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 内容区域
            Expanded(
              child: _activeTab == 0
                  ? _buildNewProjectTab()
                  : _buildImportRepoTab(),
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建 Tab 按钮
  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
          _error = '';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            children: [
              // Emoji Selector
              const Text(
                'Choose an emoji for your project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select an emoji that represents your project',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _popularEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _popularEmojis[index];
                    final isSelected = _selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = emoji;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Integration Options
              const Text(
                'Integrations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional: Enable services for your project',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: Column(
                  children: [
                    // Database Integration
                    SwitchListTile(
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.storage, color: Colors.blue, size: 20),
                      ),
                      title: const Text('Database (Neon)'),
                      subtitle: const Text('PostgreSQL database with automatic setup'),
                      value: _enableDatabase,
                      onChanged: (value) {
                        setState(() {
                          _enableDatabase = value;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    const Divider(height: 1, indent: 72),
                    // Payment Integration
                    SwitchListTile(
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.payment, color: Colors.green, size: 20),
                      ),
                      title: const Text('Payment (Stripe)'),
                      subtitle: const Text('Accept payments with Stripe integration'),
                      value: _enablePayment,
                      onChanged: (value) {
                        setState(() {
                          _enablePayment = value;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Project Name
              const Text(
                'Project Name',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a name for your project or generate with AI',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _projectNameController,
                      onChanged: (value) {
                        // Real-time validation
                        final error = _validateProjectName(value.trim());
                        setState(() {
                          _projectNameError = error;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Project Name',
                        hintText: 'my-awesome-project',
                        border: const OutlineInputBorder(),
                        errorText: _projectNameError,
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _descriptionController.text.trim().isEmpty ||
                              _isGeneratingName
                          ? null
                          : _generateProjectName,
                      icon: _isGeneratingName
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _isGeneratingName ? 'Generating...' : 'Generate',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Project Description
              const Text(
                'Describe your project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Who is the target user? What problem do they have? How does your solution solve it?',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 6,
                onChanged: (value) {
                  // Real-time validation
                  final error = _validateDescription(value.trim());
                  setState(() {
                    _descriptionError = error;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter project description...',
                  border: const OutlineInputBorder(),
                  errorText: _descriptionError,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: Include target user, problem, solution approach, and key flows.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Tags Section
              const Text(
                'Tags',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Add tags to help categorize your project',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              // Add Tag Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Add Tag',
                        hintText: 'e.g., web-app, e-commerce, ai',
                        border: const OutlineInputBorder(),
                        errorText: _tagError,
                        errorMaxLines: 2,
                      ),
                      onSubmitted: (value) {
                        _addTag(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _addTag(_tagController.text);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tags Chips
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      deleteIcon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurface),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _shouldEnableCreateButton()
                      ? _handleCreateProject
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Project'),
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
            children: [
              const Text(
                'Import Public Repository',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Clone and mirror a public GitHub repository into the organization',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Public Repo URL',
                  hintText: 'https://github.com/owner/repo',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'my-project',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoNameController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _urlController.text.trim().isEmpty ||
                          _nameController.text.trim().isEmpty
                      ? null
                      : _handleImportRepo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Import to Org'),
                ),
              ),
            ],
          );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        const Text(
          'Creating your project...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This may take a few seconds',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
        ),
      ],
    );
  }

  /// AI 生成项目名称
  Future<void> _generateProjectName() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Please enter a project description first';
      });
      return;
    }

    setState(() {
      _isGeneratingName = true;
      _error = '';
    });

    try {
      final d1vaiService = D1vaiService();

      // 使用 AI 生成项目元数据
      final metadata = await d1vaiService.generateProjectMeta(
        prompt: description,
        maxDescLen: 500,
      );

      if (!mounted) return;

      final generatedName = metadata['project_name'] as String?;
      final generatedTags = metadata['tags'] as List<dynamic>?;

      setState(() {
        if (generatedName != null && generatedName.isNotEmpty) {
          _projectNameController.text = generatedName;
        }
        if (generatedTags != null && generatedTags.isNotEmpty) {
          _tags = generatedTags.cast<String>();
        }
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Generated',
        message: 'Project name and tags generated successfully!',
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to generate project name: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingName = false;
        });
      }
    }
  }

  /// 添加标签
  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;

    // Validate tag
    final trimmedTag = tag.trim();
    if (trimmedTag.length > 20) {
      setState(() {
        _tagError = 'Tag must be 20 characters or less';
      });
      return;
    }

    if (_tags.length >= 10) {
      setState(() {
        _tagError = 'Maximum 10 tags allowed';
      });
      return;
    }

    if (_tags.contains(trimmedTag)) {
      setState(() {
        _tagError = 'Tag already exists';
      });
      return;
    }

    setState(() {
      _tags.add(trimmedTag);
      _tagError = null;
    });
    _tagController.clear();
  }

  /// 移除标签
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _tagError = null;
    });
  }

  /// 验证项目名称
  String? _validateProjectName(String name) {
    if (name.isEmpty) {
      return 'Project name is required';
    }

    if (name.length < 3) {
      return 'Must be at least 3 characters';
    }

    if (name.length > 30) {
      return 'Must be 30 characters or less';
    }

    // Check for valid characters (letters, numbers, hyphens, underscores)
    final nameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!nameRegex.hasMatch(name)) {
      return 'Only letters, numbers, hyphens, and underscores allowed';
    }

    // Cannot start or end with hyphen
    if (name.startsWith('-') || name.endsWith('-')) {
      return 'Cannot start or end with hyphen';
    }

    return null;
  }

  /// 验证项目描述
  String? _validateDescription(String description) {
    if (description.isEmpty) {
      return 'Project description is required';
    }

    if (description.length < 10) {
      return 'Must be at least 10 characters';
    }

    if (description.length > 500) {
      return 'Must be 500 characters or less';
    }

    return null;
  }

  /// 检查是否应该启用创建按钮
  bool _shouldEnableCreateButton() {
    final description = _descriptionController.text.trim();
    final projectName = _projectNameController.text.trim();

    // Check if required fields are empty
    if (description.isEmpty || projectName.isEmpty) {
      return false;
    }

    // Check if there are any validation errors
    if (_validateProjectName(projectName) != null) {
      return false;
    }

    if (_validateDescription(description) != null) {
      return false;
    }

    if (_tagError != null) {
      return false;
    }

    return true;
  }

  /// 处理创建项目
  Future<void> _handleCreateProject() async {
    final description = _descriptionController.text.trim();
    final projectName = _projectNameController.text.trim();

    // Validate inputs
    final projectNameError = _validateProjectName(projectName);
    final descriptionError = _validateDescription(description);

    if (projectNameError != null || descriptionError != null) {
      setState(() {
        _projectNameError = projectNameError;
        _descriptionError = descriptionError;
        _error = 'Please fix the errors above';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _projectNameError = null;
      _descriptionError = null;
    });

    try {
      final d1vaiService = D1vaiService();

      // 使用 AI 生成项目元数据，并传递集成选项
      final result = await d1vaiService.createProjectWithIntegrations(
        prompt: description,
        maxDescLen: 500,
        enableDatabase: _enableDatabase,
        enablePay: _enablePayment,
      );

      if (!mounted) return;

      // 更新项目名称为用户指定的名称
      final projectId = result['project_id'] as String?;
      if (projectId != null) {
        final updateData = {
          'project_name': projectName,
          'emoji': _selectedEmoji,
          'tags': _tags,
        };
        await d1vaiService.updateUserProject(projectId, updateData);
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

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project created successfully!',
      );

      // 跳转到项目列表
      router.push('/projects');
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
      // 模拟导入仓库
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showSuccess(
          context,
          title: 'Success',
          message: 'Repository imported successfully!',
        );

        // 跳转到项目列表
        context.push('/projects');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to import repository: $e';
      });
    }
  }
}
