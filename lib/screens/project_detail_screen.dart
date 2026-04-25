import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../core/auth_expiry_bus.dart';
import '../l10n/app_localizations.dart';
import 'dart:ui';
import '../widgets/skeletons/project_overview_skeleton.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String? initialTab;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialTab,
  });

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
    _TabItem('project_detail_tab_overview', 'Overview', Icons.dashboard),
    _TabItem('project_detail_tab_chat', 'Chat', Icons.chat),
    _TabItem('project_detail_tab_environment', 'Environment', Icons.key),
    _TabItem('project_detail_tab_database', 'Database', Icons.storage),
    _TabItem('project_detail_tab_github', 'GitHub', Icons.code),
    _TabItem('project_detail_tab_payment', 'Payment', Icons.payment),
    _TabItem('project_detail_tab_deploy', 'Deploy', Icons.cloud_upload),
    _TabItem('project_detail_tab_analytics', 'Analytics', Icons.analytics),
  ];

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _tabIndexFromName(widget.initialTab),
    );

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginRequiredDialog();
      });
      return;
    }

    // Populate immediately (enables Hero on first frame), then refresh async.
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final cached = projectProvider.getProjectById(widget.projectId);
    if (cached != null) {
      _project = cached;
      _isLoading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProject();
    });
  }

  int _tabIndexFromName(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.isEmpty) return 0;
    switch (t) {
      case 'overview':
        return 0;
      case 'chat':
        return 1;
      case 'environment':
      case 'env':
      case 'variables':
      case 'api':
        return 2;
      case 'database':
      case 'db':
        return 3;
      case 'github':
        return 4;
      case 'payment':
      case 'billing':
        return 5;
      case 'deploy':
      case 'deployment':
      case 'logs':
        return 6;
      case 'analytics':
        return 7;
      default:
        return 0;
    }
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
        AuthExpiryBus.trigger(endpoint: '/api/projects/${widget.projectId}');
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
    final preview = (project.preferredPreviewUrl ?? '').trim();
    final raw = (prod.isNotEmpty ? prod : preview).trim();
    if (raw.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: _t('project_detail_share_title', 'Share'),
        message: _t(
          'project_detail_share_no_url',
          'No preview/production URL available yet.',
        ),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      SnackBarHelper.showError(
        context,
        title: _t('project_detail_share_title', 'Share'),
        message: _t(
          'project_detail_share_invalid_url',
          'Invalid URL: {url}',
        ).replaceAll('{url}', raw),
      );
      return;
    }
    ShareSheet.show(
      context,
      url: uri,
      title: project.projectName,
      message: project.projectDescription.trim().isNotEmpty
          ? project.projectDescription.trim()
          : (prod.isNotEmpty
                ? _t('project_detail_share_production_link', 'Production link')
                : _t('project_detail_share_preview_link', 'Preview link')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _buildGlassmorphicAppBar(context),
        ),
        body: const ProjectOverviewSkeleton(),
      );
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
              Text(
                _t(
                  'project_detail_error_text',
                  'Error: {error}',
                ).replaceAll('{error}', _error ?? ''),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProject,
                child: Text(_t('retry', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final project = _project;
    if (project == null) {
      return Scaffold(
        body: Center(
          child: Text(_t('project_detail_not_found', 'Project not found')),
        ),
      );
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
            previewUrl: project.preferredPreviewUrl,
          ),
          ProjectApiTab(projectId: project.id),
          ProjectDatabaseTab(
            project: project,
            onAskAi: _handleAskAi,
            onRefreshProject: _loadProject,
          ),
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
                  tooltip: _t('project_detail_share_title', 'Share'),
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
                  tabs: _tabs
                      .map(
                        (tab) => D1VTab(
                          icon: tab.icon,
                          text: _t(tab.labelKey, tab.fallback),
                        ),
                      )
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
  final String labelKey;
  final String fallback;
  final IconData icon;

  const _TabItem(this.labelKey, this.fallback, this.icon);
}
