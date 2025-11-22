import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
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
                color: Colors.grey.shade200,
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
                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
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
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
            color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 构建新建项目标签
  Widget _buildNewProjectTab() {
    return _isLoading
        ? _buildLoadingState()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe your project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Who is the target user? What problem do they have? How does your solution solve it?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter project description...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: Include target user, problem, solution approach, and key flows.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _descriptionController.text.trim().isEmpty
                      ? null
                      : _handleCreateProject,
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Public Repo URL',
                  hintText: 'https://github.com/owner/repo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
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
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
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
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }

  /// 处理创建项目
  Future<void> _handleCreateProject() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Please enter a project description';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 模拟创建项目
      await Future.delayed(const Duration(seconds: 2));

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

      widget.onCreated?.call(
        UserProject(
          id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
          projectName: 'My Awesome Project',
          projectDescription: description,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          userId: 1000,
          projectPort: 3000,
          emoji: '🚀',
          tags: [],
          status: 'active',
        ),
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
