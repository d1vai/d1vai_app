import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../l10n/app_localizations.dart';
import '../widgets/snackbar_helper.dart';

/// 项目管理设置页面
///
/// 提供项目管理功能，包括：
/// - 查看项目列表
/// - 创建新项目
/// - 重命名项目
/// - 删除项目
/// - 查看项目详情
class ProjectSettingsScreen extends StatefulWidget {
  const ProjectSettingsScreen({super.key});

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProjectProvider>(context, listen: false).loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('projects') ?? 'Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<ProjectProvider>(context, listen: false).refresh();
            },
          ),
        ],
      ),
      body: Consumer<ProjectProvider>(
        builder: (context, projectProvider, child) {
          if (projectProvider.isLoading && projectProvider.projects.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (projectProvider.error != null && projectProvider.projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load projects',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      projectProvider.refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final projects = projectProvider.projects;

          if (projects.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => projectProvider.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        project.emoji ?? project.projectName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      project.projectName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          project.projectDescription.isNotEmpty
                              ? project.projectDescription
                              : 'No description',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Port: ${project.projectPort}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) => _handleMenuAction(value, project),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 18),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/projects/${project.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProjectDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first project to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateProjectDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Project'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理菜单操作
  void _handleMenuAction(String action, UserProject project) {
    switch (action) {
      case 'view':
        context.push('/projects/${project.id}');
        break;
      case 'rename':
        _showRenameDialog(project);
        break;
      case 'delete':
        _showDeleteDialog(project);
        break;
    }
  }

  /// 显示创建项目对话框
  void _showCreateProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreateProjectDialog(),
    );
  }

  /// 显示重命名对话框
  void _showRenameDialog(UserProject project) {
    final nameController = TextEditingController(text: project.projectName);
    final descController = TextEditingController(text: project.projectDescription);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _renameProject(
                project,
                nameController.text,
                descController.text,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// 显示删除确认对话框
  void _showDeleteDialog(UserProject project) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete "${project.projectName}"? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _deleteProject(project),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// 重命名项目
  Future<void> _renameProject(UserProject project, String name, String description) async {
    try {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      await projectProvider.updateProject(project.id, {
        'project_name': name,
        'project_description': description,
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project renamed successfully',
      );
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to rename project: $e',
      );
    }
  }

  /// 删除项目
  Future<void> _deleteProject(UserProject project) async {
    try {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      await projectProvider.deleteProject(project.id);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project deleted successfully',
      );
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to delete project: $e',
      );
    }
  }
}

/// 创建项目对话框
class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createProject,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  /// 创建项目
  Future<void> _createProject() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Project name is required',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      await projectProvider.createProject({
        'project_name': name,
        'project_description': descController.text.trim(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project created successfully',
      );
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to create project: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
