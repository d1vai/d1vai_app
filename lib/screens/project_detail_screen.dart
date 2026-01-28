import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../services/d1vai_service.dart';
import '../utils/error_utils.dart';
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
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';
import '../theme/d1v_theme_colors.dart';
import 'dart:ui';

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

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginRequiredDialog();
      });
      return;
    }

    // Populate immediately (enables Hero on first frame), then refresh async.
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final cached = projectProvider.getProjectById(widget.projectId);
    if (cached != null) {
      _project = cached;
      _isLoading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProject();
    });
  }

  Future<void> _loadProject() async {
    final shouldShowBlocking = _project == null;
    setState(() {
      _isLoading = shouldShowBlocking;
      _error = null;
    });

    try {
      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );

      var project = projectProvider.getProjectById(widget.projectId);
      final hasBranch =
          (project?.workspaceCurrentBranch ??
                  project?.repositoryCurrentBranch ??
                  '')
              .trim()
              .isNotEmpty;

      // Fast-path: show cached list item immediately to avoid blank UI.
      if (project != null) {
        setState(() {
          _project = project;
          _isLoading = false;
        });
      }

      // Always refresh if branch is missing (overview relies on it, matches web).
      if (project == null || !hasBranch) {
        final service = D1vaiService();
        final fresh = await service.getUserProjectById(widget.projectId);
        if (!mounted) return;
        setState(() {
          _project = fresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      final message = humanizeError(e);
      if (isAuthExpiredText(message)) {
        if (!mounted) return;
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (!mounted) return;
        context.go('/login');
        return;
      }
      setState(() {
        _error = message;
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

  void _shareProject() {
    final project = _project;
    if (project == null) return;
    final prod = (project.latestProdDeploymentUrl ?? '').trim();
    final preview = (project.latestPreviewUrl ?? '').trim();
    final raw = (prod.isNotEmpty ? prod : preview).trim();
    if (raw.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'Share',
        message: 'No preview/production URL available yet.',
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      SnackBarHelper.showError(
        context,
        title: 'Share',
        message: 'Invalid URL: $raw',
      );
      return;
    }
    ShareSheet.show(
      context,
      url: uri,
      title: project.projectName,
      message:
          project.projectDescription.trim().isNotEmpty
              ? project.projectDescription.trim()
              : (prod.isNotEmpty ? 'Production link' : 'Preview link'),
    );
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildGlassmorphicAppBar(context),
      ),
      body: D1VTabBarView(
        controller: _tabController,
        children: [
          ProjectOverviewTab(project: project, onRefreshProject: _loadProject),
          ProjectChatTab(
            key: _chatTabKey,
            projectId: project.id,
            previewUrl: project.latestPreviewUrl,
          ),
          ProjectDatabaseTab(
            project: project,
            onAskAi: _handleAskAi,
            onRefreshProject: _loadProject,
          ),
          ProjectApiTab(projectId: project.id),
          ProjectGithubTab(project: project),
          ProjectPaymentTab(projectId: project.id, onAskAi: _handleAskAi),
          ProjectDeployTab(
            project: project,
            onAskAi: _handleAskAi,
            onRefreshProject: _loadProject,
          ),
          ProjectAnalyticsTab(
            project: project,
            onAskAi: _handleAskAi,
            onRefreshProject: _loadProject,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = D1VColors.getPrimaryGradient(context);
    final activeText = D1VColors.getActiveText(context);
    final inactiveText = D1VColors.getInactiveText(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: isDark ? null : D1VColors.getGlowShadows(context, 1.0),
      ),
      child: ClipRRect(
        child: Stack(
          children: [
            // 渐变背景
            Container(decoration: BoxDecoration(gradient: gradient)),
            // 磨砂玻璃层 (Dark Mode)
            if (isDark)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: D1VColors.deepBlueDark.withValues(alpha: 0.6 * 255),
                  ),
                ),
              ),
            // AppBar 内容
            AppBar(
              titleSpacing: 0,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: activeText,
              actions: [
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share),
                  onPressed: _shareProject,
                ),
              ],
              title: ClipRect(
                child: D1VTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: activeText,
                  unselectedLabelColor: inactiveText,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs:
                      _tabs
                          .map((tab) => D1VTab(icon: tab.icon, text: tab.label))
                          .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;

  const _TabItem(this.label, this.icon);
}
