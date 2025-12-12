import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../services/d1vai_service.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/project_analytics/project_analytics_tab.dart';
import '../widgets/project_api/project_api_tab.dart';
import '../widgets/project_chat/project_chat_tab.dart';
import '../widgets/project_database/project_database_tab.dart';
import '../widgets/project_deploy/project_deploy_tab.dart';
import '../widgets/project_github/project_github_tab.dart';
import '../widgets/project_overview/project_overview_tab.dart';
import '../widgets/project_payment/project_payment_tab.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../theme/d1v_theme_colors.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<ProjectChatTabState> _chatTabKey =
      GlobalKey<ProjectChatTabState>();

  UserProject? _project;
  bool _isLoading = true;
  String? _error;

  final List<_TabItem> _tabs = const [
    _TabItem('Overview', Icons.dashboard),
    _TabItem('Chat', Icons.chat),
    _TabItem('Database', Icons.storage),
    _TabItem('API', Icons.api),
    _TabItem('GitHub', Icons.code),
    _TabItem('Payment', Icons.payment),
    _TabItem('Deploy', Icons.cloud_upload),
    _TabItem('Analytics', Icons.analytics),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showLoginRequiredDialog();
      } else {
        _loadProject();
      }
    });
  }

  Future<void> _loadProject() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );

      var project = projectProvider.getProjectById(widget.projectId);
      if (project == null) {
        final service = D1vaiService();
        project = await service.getUserProjectById(widget.projectId);
      }

      setState(() {
        _project = project;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  /// 供子 Tab 调用，发送一个问题到 Chat Tab 并自动切换过去
  void _handleAskAi(String prompt) {
    // 切换到 Chat Tab（索引 1）
    _tabController.animateTo(1);

    // 等待 Tab 构建完成后再发送消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _chatTabKey.currentState;
      state?.sendInitialPrompt(prompt);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProject,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final project = _project;
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Project not found')));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: SizedBox(
          width: double.infinity,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: D1VColors.getFirePurple(
                context,
              ).withValues(alpha: 0.2 * 255),
              border: Border.all(
                color: D1VColors.getFirePurple(context),
                width: 2,
              ),
            ),
            labelColor: D1VColors.getFirePurple(context),
            unselectedLabelColor: D1VColors.getInactive(context),
            tabs: _tabs
                .map(
                  (tab) => Tab(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            tab.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      body: D1VTabBarView(
        controller: _tabController,
        children: [
          ProjectOverviewTab(project: project),
          ProjectChatTab(
            key: _chatTabKey,
            projectId: project.id,
            previewUrl: project.latestPreviewUrl,
          ),
          ProjectDatabaseTab(projectId: project.id, onAskAi: _handleAskAi),
          ProjectApiTab(projectId: project.id),
          const ProjectGithubTab(),
          ProjectPaymentTab(projectId: project.id, onAskAi: _handleAskAi),
          ProjectDeployTab(project: project, onAskAi: _handleAskAi),
          ProjectAnalyticsTab(projectId: project.id, onAskAi: _handleAskAi),
        ],
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;

  const _TabItem(this.label, this.icon);
}
