import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/models/user.dart';
import 'package:d1vai_app/models/project.dart';
import 'package:d1vai_app/models/prompt_activity.dart';
import 'package:d1vai_app/services/d1vai_service.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/create_project_dialog.dart';
import 'package:d1vai_app/widgets/card.dart';
import 'package:d1vai_app/core/theme/app_colors.dart';
import 'package:d1vai_app/utils/error_utils.dart';
import 'package:d1vai_app/core/auth_expiry_bus.dart';
import 'package:d1vai_app/widgets/login_required_view.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/widgets/compact_selector.dart';
import 'package:d1vai_app/widgets/dashboard/workspace_status_badge.dart';
import 'package:d1vai_app/widgets/prompt_activity_heatmap.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';
import 'package:d1vai_app/screens/projects/widgets/project_card_tile.dart';
import 'package:d1vai_app/widgets/skeletons/dashboard_skeleton.dart';
import 'package:d1vai_app/widgets/skeletons/prompt_activity_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const String _allProjectsOptionValue = '__all_projects__';
  static const int _promptActivityDays =
      161; // 23 weeks, denser timeline while staying readable on mobile.

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<UserProject> _searchResults = [];
  bool _didAutoLoadAfterLogin = false;
  Future<PromptDailyActivity>? _promptActivityFuture;
  String? _promptActivityProjectId;
  final D1vaiService _service = D1vaiService();
  final WorkspaceService _workspaceService = WorkspaceService();

  WorkspaceStateInfo? _workspaceState;
  WorkspacePhase _workspacePhase = WorkspacePhase.unknown;
  bool _workspaceChecking = true;
  String? _workspaceError;
  bool _workspacePollInFlight = false;
  bool _workspaceActiveInFlight = false;
  Timer? _workspacePollTimer;
  bool _didInitWorkspaceStatus = false;

  late AnimationController _animationController;
  late AnimationController _workspaceBreathController;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _workspaceBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    // 加载项目数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadData();
    });
  }

  void _maybeLoadData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_didAutoLoadAfterLogin) return;
    if (auth.isAuthenticated) {
      _didAutoLoadAfterLogin = true;
      _loadData();
      _ensureWorkspaceStatusBootstrap();
    }
  }

  void _ensureWorkspaceStatusBootstrap() {
    if (_didInitWorkspaceStatus) return;
    _didInitWorkspaceStatus = true;
    unawaited(_bootstrapWorkspaceStatus());
  }

  void _scheduleWorkspacePoll() {
    _workspacePollTimer?.cancel();
    if (!_didInitWorkspaceStatus || !mounted) return;
    final delay =
        (!_workspaceChecking && _workspacePhase == WorkspacePhase.ready)
        ? const Duration(seconds: 30)
        : const Duration(seconds: 5);
    _workspacePollTimer = Timer(delay, () {
      if (!mounted || !_didInitWorkspaceStatus) return;
      unawaited(_refreshWorkspaceStatus(bypassCache: true));
    });
  }

  Future<void> _refreshWorkspaceStatus({required bool bypassCache}) async {
    if (!_didInitWorkspaceStatus || _workspacePollInFlight) return;
    _workspacePollInFlight = true;
    try {
      final st = await _workspaceService.getWorkspaceStatus(
        bypassCache: bypassCache,
      );
      if (!mounted || !_didInitWorkspaceStatus) return;
      setState(() {
        _workspaceState = st;
        _workspacePhase = normalizeWorkspacePhase(st);
        _workspaceChecking = false;
        _workspaceError = null;
      });
    } catch (e) {
      if (!mounted || !_didInitWorkspaceStatus) return;
      setState(() {
        _workspaceChecking = false;
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = e.toString();
      });
    } finally {
      _workspacePollInFlight = false;
      _scheduleWorkspacePoll();
    }
  }

  Future<void> _requestWorkspaceActive({
    bool silent = false,
    bool fromTap = false,
  }) async {
    if (!_didInitWorkspaceStatus || _workspaceActiveInFlight) return;
    final phase = _workspacePhase;
    if (fromTap &&
        (_workspaceChecking ||
            phase == WorkspacePhase.ready ||
            phase == WorkspacePhase.starting)) {
      await _refreshWorkspaceStatus(bypassCache: true);
      return;
    }

    setState(() {
      _workspaceActiveInFlight = true;
      _workspaceError = null;
      if (!_workspaceChecking && _workspacePhase != WorkspacePhase.ready) {
        _workspacePhase = WorkspacePhase.starting;
      }
    });

    try {
      final discovered = await _workspaceService.discoverWorkspace();
      if (!mounted || !_didInitWorkspaceStatus) return;
      setState(() {
        _workspaceState = discovered;
        _workspacePhase = normalizeWorkspacePhase(discovered);
        _workspaceChecking = false;
        _workspaceError = null;
      });
      await _refreshWorkspaceStatus(bypassCache: true);
    } catch (e) {
      if (!mounted || !_didInitWorkspaceStatus) return;
      setState(() {
        _workspaceChecking = false;
        _workspacePhase = WorkspacePhase.error;
        _workspaceError = e.toString();
      });
      if (!silent) {
        SnackBarHelper.showError(
          context,
          title: _t('dashboard_workspace_title', 'Workspace'),
          message: _t(
            'dashboard_workspace_start_failed',
            'Failed to start workspace: {error}',
          ).replaceAll('{error}', e.toString()),
        );
      }
    } finally {
      if (mounted && _didInitWorkspaceStatus) {
        setState(() {
          _workspaceActiveInFlight = false;
        });
      }
      _scheduleWorkspacePoll();
    }
  }

  Future<void> _bootstrapWorkspaceStatus() async {
    await _refreshWorkspaceStatus(bypassCache: true);
    if (!mounted || !_didInitWorkspaceStatus) return;
    if (_workspacePhase != WorkspacePhase.ready) {
      await _requestWorkspaceActive(silent: true);
    }
  }

  String _workspaceStatusLabel() {
    if (_workspaceActiveInFlight) {
      return _t('dashboard_workspace_status_starting', 'Starting');
    }
    if (_workspaceChecking) {
      return _t('dashboard_workspace_status_checking', 'Checking');
    }
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return _t('dashboard_workspace_status_ready', 'Ready');
      case WorkspacePhase.starting:
        return _t('dashboard_workspace_status_starting', 'Starting');
      case WorkspacePhase.syncing:
        return _t('dashboard_workspace_status_syncing', 'Syncing');
      case WorkspacePhase.standby:
        return _t('dashboard_workspace_status_standby', 'Standby');
      case WorkspacePhase.archived:
        return _t('dashboard_workspace_status_archived', 'Archived');
      case WorkspacePhase.error:
        return _t('dashboard_workspace_status_error', 'Error');
      case WorkspacePhase.unknown:
        return _t('dashboard_workspace_status_unknown', 'Unknown');
    }
  }

  Color _workspaceDotColor() {
    if (_workspaceChecking) return Colors.amber;
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return Colors.green;
      case WorkspacePhase.starting:
        return Colors.amber;
      case WorkspacePhase.syncing:
        return Colors.purple;
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        return Colors.grey;
      case WorkspacePhase.error:
        return Colors.red;
      case WorkspacePhase.unknown:
        return Colors.grey;
    }
  }

  String _workspaceTooltip() {
    final parts = <String>[
      _t(
        'dashboard_workspace_tooltip',
        'Workspace {status}',
      ).replaceAll('{status}', _workspaceStatusLabel()),
    ];
    final raw = _workspaceState?.status;
    if (raw != null && raw.trim().isNotEmpty) {
      parts.add('status=$raw');
    }
    final ip = _workspaceState?.ip;
    final port = _workspaceState?.port;
    if (ip != null && ip.trim().isNotEmpty && port != null) {
      parts.add('$ip:$port');
    }
    if (_workspaceError != null && _workspaceError!.trim().isNotEmpty) {
      parts.add(_workspaceError!);
    }
    return parts.join(' · ');
  }

  bool _workspaceIsLoadingVisual() {
    return _workspaceActiveInFlight ||
        _workspaceChecking ||
        _workspacePhase == WorkspacePhase.starting ||
        _workspacePhase == WorkspacePhase.syncing;
  }

  Widget _buildWorkspaceStatusWidget({bool inAppBar = false}) {
    final dotColor = _workspaceDotColor();
    final loadingVisual = _workspaceIsLoadingVisual();
    final statusText = _workspaceStatusLabel();
    return WorkspaceStatusBadge(
      inAppBar: inAppBar,
      statusText: statusText,
      tooltip: _workspaceTooltip(),
      dotColor: dotColor,
      breathing: loadingVisual,
      breathAnimation: _workspaceBreathController,
      onTap: _workspaceActiveInFlight
          ? null
          : () => unawaited(_requestWorkspaceActive(fromTap: true)),
    );
  }

  /// 加载数据
  Future<void> _loadData() async {
    // Start heatmap fetch early; UI will render as soon as data arrives.
    if (mounted) {
      setState(() {
        _promptActivityFuture = _service.getPromptDailyActivity(
          days: _promptActivityDays,
          projectId: _promptActivityProjectId,
        );
      });
    } else {
      _promptActivityFuture = _service.getPromptDailyActivity(
        days: _promptActivityDays,
        projectId: _promptActivityProjectId,
      );
    }
    await Provider.of<ProjectProvider>(context, listen: false).loadProjects();
    if (mounted) {
      _animationController.forward(from: 0);
    }
  }

  void _reloadPromptActivity() {
    setState(() {
      _promptActivityFuture = _service.getPromptDailyActivity(
        days: _promptActivityDays,
        projectId: _promptActivityProjectId,
      );
    });
  }

  String _projectDisplayName(UserProject p) {
    final name = p.projectName.trim();
    return name.isEmpty ? p.id : name;
  }

  String _allProjectsLabel(BuildContext context) {
    return _t('dashboard_all_projects', 'All projects');
  }

  Widget _buildPromptActivityHeaderTrailing(ProjectProvider projectProvider) {
    final projects = projectProvider.projects;
    final isLoading = projectProvider.isLoading;
    final projectsForMenu = projects.take(80).toList(growable: false);
    UserProject? selectedProject;
    final selectedId = _promptActivityProjectId;
    if (selectedId != null) {
      for (final p in projectsForMenu) {
        if (p.id == selectedId) {
          selectedProject = p;
          break;
        }
      }
    }

    final pickerLabel = selectedProject == null
        ? _allProjectsLabel(context)
        : _projectDisplayName(selectedProject);
    final options = <CompactSelectorOption>[
      CompactSelectorOption(
        value: _allProjectsOptionValue,
        label: _allProjectsLabel(context),
      ),
      ...projectsForMenu.map(
        (p) =>
            CompactSelectorOption(value: p.id, label: _projectDisplayName(p)),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactSelector(
          options: options,
          value: _promptActivityProjectId ?? _allProjectsOptionValue,
          displayLabel: pickerLabel,
          placeholder: _allProjectsLabel(context),
          tooltip: _t('dashboard_switch_project', 'Switch project'),
          leadingIcon: Icons.folder_open_rounded,
          minWidth: 100,
          maxWidth: 142,
          isLoading: isLoading,
          onChanged: isLoading
              ? null
              : (value) {
                  setState(() {
                    _promptActivityProjectId = value == _allProjectsOptionValue
                        ? null
                        : value;
                  });
                  _reloadPromptActivity();
                },
        ),
        if (selectedProject != null)
          IconButton(
            tooltip: _t('dashboard_open_project', 'Open project'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            onPressed: () {
              final pid = _promptActivityProjectId;
              if (pid == null) return;
              context.push('/projects/$pid');
            },
          ),
        if (selectedProject != null && isLoading) ...[const SizedBox(width: 2)],
      ],
    );
  }

  @override
  void dispose() {
    _workspacePollTimer?.cancel();
    _workspaceBreathController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 执行搜索
  void _performSearch(String query) {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
    } else {
      final results = provider.searchProjects(query.trim());
      setState(() {
        _searchResults = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final projectProvider = Provider.of<ProjectProvider>(context);

    if (user != null && !_didInitWorkspaceStatus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureWorkspaceStatusBootstrap();
      });
    }

    bool pendingLoad = false;
    if (user != null &&
        !_didAutoLoadAfterLogin &&
        !projectProvider.isLoading &&
        projectProvider.projects.isEmpty &&
        projectProvider.error == null) {
      _didAutoLoadAfterLogin = true;
      pendingLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadData();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _t('projects_search_hint', 'Search projects...'),
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (query) {
                  _performSearch(query);
                },
              )
            : Row(
                children: [
                  Text(_t('dashboard', 'Dashboard')),
                  if (user != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildWorkspaceStatusWidget(inAppBar: true),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          IconButton(
            tooltip: _t('dashboard_action_chat', 'Chat'),
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              context.push('/chat');
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
        ],
      ),
      body: (projectProvider.isInitialLoading || pendingLoad)
          ? _buildShimmer()
          : _buildContent(user, context, projectProvider),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton(
              onPressed: () {
                CreateProjectDialog.show(context);
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildShimmer() {
    return const DashboardSkeleton();
  }

  Widget _buildContent(
    User? user,
    BuildContext context,
    ProjectProvider projectProvider,
  ) {
    final loc = AppLocalizations.of(context);
    final stats = projectProvider.getProjectStats();

    // 如果有错误，显示错误提示
    if (projectProvider.error != null && projectProvider.projects.isEmpty) {
      return _buildErrorState(context, projectProvider);
    }

    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('dashboard_welcome', 'Welcome, {user}!').replaceAll(
              '{user}',
              user?.email ?? _t('dashboard_user_fallback', 'User'),
            ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),

          // 项目统计卡片
          _buildStatsCards(stats, context),
          const SizedBox(height: 24),

          // Prompt activity heatmap (GitHub-style)
          if (user == null)
            const SizedBox.shrink()
          else
            FutureBuilder<PromptDailyActivity>(
              future: _promptActivityFuture,
              builder: (context, snapshot) {
                if (_promptActivityFuture == null) {
                  return const SizedBox.shrink();
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const PromptActivitySkeleton();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return CustomCard(
                    glass: true,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        loc?.translate('failed_to_load') ?? 'Failed to load',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }
                return PromptActivityHeatmap(
                  activity: snapshot.data!,
                  headerTrailing: _buildPromptActivityHeaderTrailing(
                    projectProvider,
                  ),
                  onDayTap: (isoDate, count) {
                    final message =
                        _t(
                              'dashboard_prompt_activity_day_message',
                              '{count} prompts on {date}',
                            )
                            .replaceAll('{count}', count.toString())
                            .replaceAll('{date}', isoDate);
                    SnackBarHelper.showInfo(
                      context,
                      title: _t(
                        'dashboard_prompt_activity_title',
                        'Prompt activity',
                      ),
                      message: message,
                      position: SnackBarPosition.top,
                      duration: const Duration(seconds: 2),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 24),

          // 最近项目
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSearching && _searchController.text.isNotEmpty
                    ? _t(
                        'dashboard_search_results',
                        'Search Results ({count})',
                      ).replaceAll('{count}', _searchResults.length.toString())
                    : (_t('recent_projects', 'Recent Projects')),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: user == null
                    ? () => context.go('/login')
                    : () {
                        final q = _isSearching
                            ? _searchController.text.trim()
                            : '';
                        final location = q.isEmpty
                            ? '/projects'
                            : '/projects?q=${Uri.encodeQueryComponent(q)}';
                        context.push(location);
                      },
                child: Text(_t('dashboard_view_all', 'View All')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (user == null)
            LoginRequiredView(
              variant: LoginRequiredVariant.full,
              message:
                  loc?.translate('login_required_dashboard_message') ??
                  'Please login first.',
              onAction: () => context.go('/login'),
            )
          else
            _buildProjectList(
              context,
              projectProvider,
              isSearchResults:
                  _isSearching && _searchController.text.isNotEmpty,
            ),
          const SizedBox(height: 80), // Bottom padding for FAB
        ],
      ),
    );

    if (user == null) return content;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _promptActivityFuture = _service.getPromptDailyActivity(
            days: _promptActivityDays,
            projectId: _promptActivityProjectId,
          );
        });
        await _refreshWorkspaceStatus(bypassCache: true);
        await projectProvider.refresh();
      },
      child: content,
    );
  }

  /// 构建项目统计卡片
  Widget _buildStatsCards(Map<String, int> stats, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _t('dashboard_stats_total', 'Total'),
            stats['total'].toString(),
            Icons.folder,
            AppColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _t('dashboard_stats_active', 'Active'),
            stats['active'].toString(),
            Icons.play_circle_outline,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _t('dashboard_stats_archived', 'Archived'),
            stats['archived'].toString(),
            Icons.archive,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  /// 构建单个统计卡片
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return StatCard(
      value: value,
      label: label,
      icon: icon,
      valueColor: color,
      glass: true,
    );
  }

  Widget _buildProjectList(
    BuildContext context,
    ProjectProvider projectProvider, {
    bool isSearchResults = false,
  }) {
    final List<UserProject> projects = isSearchResults
        ? _searchResults.take(5).toList()
        : projectProvider.projects.take(5).toList();

    if (projects.isEmpty) {
      return CustomCard(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _t('dashboard_no_projects_title', 'No projects yet'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'dashboard_no_projects_hint',
                  'Create your first project to get started',
                ),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  CreateProjectDialog.show(context);
                },
                icon: const Icon(Icons.add),
                label: Text(_t('create_project', 'Create Project')),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = projects[index];
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final intervalStart = index * 0.1;
            final intervalEnd = (intervalStart + 0.4).clamp(0.0, 1.0);

            final animation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                intervalStart,
                intervalEnd,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: ProjectCardTile(
            project: project,
            updatedText: _formatTimeAgo(project.updatedAt),
            onTap: () => context.push('/projects/${project.id}'),
            onChat: () => context.push('/projects/${project.id}/chat'),
          ),
        );
      },
    );
  }

  /// 格式化时间
  String _formatTimeAgo(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return _t('just_now', 'Just now');
      } else if (difference.inMinutes < 60) {
        return _t(
          'projects_time_minutes_ago',
          '{value}m ago',
        ).replaceAll('{value}', difference.inMinutes.toString());
      } else if (difference.inHours < 24) {
        return _t(
          'projects_time_hours_ago',
          '{value}h ago',
        ).replaceAll('{value}', difference.inHours.toString());
      } else if (difference.inDays < 7) {
        return _t(
          'projects_time_days_ago',
          '{value}d ago',
        ).replaceAll('{value}', difference.inDays.toString());
      } else {
        return _t('projects_time_date', '{day}/{month}/{year}')
            .replaceAll('{day}', dateTime.day.toString())
            .replaceAll('{month}', dateTime.month.toString())
            .replaceAll('{year}', dateTime.year.toString());
      }
    } catch (e) {
      return '';
    }
  }

  /// 构建错误状态
  Widget _buildErrorState(
    BuildContext context,
    ProjectProvider projectProvider,
  ) {
    final errText =
        projectProvider.error ?? _t('dashboard_unknown_error', 'Unknown error');
    final authExpired = isAuthExpiredText(errText);
    return RefreshIndicator(
      onRefresh: () async => await projectProvider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _t('dashboard_projects_load_failed', 'Failed to load projects'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              errText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await projectProvider.refresh();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(_t('retry', 'Retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (authExpired)
                  OutlinedButton.icon(
                    onPressed: () {
                      AuthExpiryBus.trigger(endpoint: '/api/projects');
                    },
                    icon: const Icon(Icons.login),
                    label: Text(_t('projects_action_relogin', 'Re-login')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
