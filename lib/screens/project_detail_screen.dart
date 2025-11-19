import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/project.dart';
import '../widgets/login_required_dialog.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<TabItem> _tabs = [
    TabItem('Overview', Icons.dashboard, 'overview'),
    TabItem('Chat', Icons.chat, 'chat'),
    TabItem('Database', Icons.storage, 'database'),
    TabItem('API', Icons.api, 'api'),
    TabItem('GitHub', Icons.code, 'github'),
    TabItem('Payment', Icons.payment, 'payment'),
    TabItem('Deploy', Icons.cloud_upload, 'deploy'),
    TabItem('Analytics', Icons.analytics, 'analytics'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showLoginRequiredDialog();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 显示登录提示对话框
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  /// 格式化时间
  String _formatTimeAgo(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final project = projectProvider.getProjectById(widget.projectId);

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.projectName ?? 'Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.icon),
                      const SizedBox(height: 4),
                      Text(tab.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
              .toList(),
          onTap: (index) {
            setState(() {});
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, project),
          _buildChatTab(context),
          _buildDatabaseTab(context),
          _buildApiTab(context),
          _buildGithubTab(context),
          _buildPaymentTab(context),
          _buildDeployTab(context),
          _buildAnalyticsTab(context),
        ],
      ),
    );
  }

  /// 构建概览标签
  Widget _buildOverviewTab(BuildContext context, UserProject? project) {
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          project.emoji ?? '🚀',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.projectName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.projectDescription,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusChip(project.status),
                      const SizedBox(width: 8),
                      Text(
                        'Updated ${_formatTimeAgo(project.updatedAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Preview URL'),
                  subtitle: Text(project.latestPreviewUrl ?? 'Not available'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    if (project.latestPreviewUrl != null) {
                      // TODO: Open preview URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening preview...')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('GitHub Repository'),
                  subtitle: Text('proj_${project.projectPort}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Open GitHub repo
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GitHub feature coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建聊天标签
  Widget _buildChatTab(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chat Feature',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat-based project editing coming soon',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// 构建数据库标签
  Widget _buildDatabaseTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.blue),
            title: const Text('Users'),
            subtitle: const Text('5 tables'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Database feature coming soon')),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('Products'),
            subtitle: const Text('3 tables'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  /// 构建 API 标签
  Widget _buildApiTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.key, color: Colors.orange),
            title: const Text('API Keys'),
            subtitle: const Text('Manage your API keys'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API feature coming soon')),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description, color: Colors.purple),
            title: const Text('API Documentation'),
            subtitle: const Text('View API documentation'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  /// 构建 GitHub 标签
  Widget _buildGithubTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GitHub Integration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your GitHub repository',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GitHub feature coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Connect GitHub'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建支付标签
  Widget _buildPaymentTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.credit_card, color: Colors.blue),
            title: const Text('Stripe Configuration'),
            subtitle: const Text('Configure payment settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment feature coming soon')),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建部署标签
  Widget _buildDeployTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deployments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Production'),
                  subtitle: const Text('Latest deployment'),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Open'),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.history, color: Colors.grey.shade600),
                  title: const Text('View Deployment History'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deployment history feature coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建分析标签
  Widget _buildAnalyticsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.show_chart, color: Colors.green),
                  title: const Text('View Analytics Dashboard'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Analytics feature coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.track_changes, color: Colors.blue),
                  title: const Text('Track Events'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建状态芯片
  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'archived':
        color = Colors.orange;
        label = 'Archived';
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 显示选项菜单
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Project'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Open edit dialog
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Duplicate Project'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Duplicate project
                },
              ),
              ListTile(
                leading: Icon(Icons.archive, color: Colors.orange),
                title: const Text('Archive Project'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Archive project
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Project',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: const Text(
            'Are you sure you want to delete this project? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Project deleted')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

/// Tab 项目
class TabItem {
  final String label;
  final IconData icon;
  final String value;

  TabItem(this.label, this.icon, this.value);
}
