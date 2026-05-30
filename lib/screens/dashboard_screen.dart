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
import 'package:d1vai_app/services/github_service.dart';
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
import 'package:d1vai_app/utils/chat_entry.dart';
import 'package:d1vai_app/utils/desktop_layout.dart';
import 'package:d1vai_app/core/theme/locale_font_helper.dart';
import 'package:d1vai_app/widgets/adaptive_modal.dart';
import 'package:d1vai_app/widgets/d1v_app_bar.dart';
import 'package:d1vai_app/widgets/import_repository_dialog.dart';

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
  final GitHubService _githubService = GitHubService();
  final WorkspaceService _workspaceService = WorkspaceService();

  WorkspaceStateInfo? _workspaceState;
  WorkspacePhase _workspacePhase = WorkspacePhase.unknown;
  bool _workspaceChecking = true;
  String? _workspaceError;
  bool _workspacePollInFlight = false;
  bool _workspaceActiveInFlight = false;
  Timer? _workspacePollTimer;
  bool _didInitWorkspaceStatus = false;
  Map<String, dynamic>? _githubDashboardRepositories;
  bool _githubDashboardLoading = false;

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
      if (!mounted) return;
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
    await Future.wait<void>([
      Provider.of<ProjectProvider>(context, listen: false).loadProjects(),
      _loadGitHubDashboardRepositories(),
    ]);
    if (mounted) {
      _animationController.forward(from: 0);
    }
  }

  Future<void> _loadGitHubDashboardRepositories() async {
    if (mounted) {
      setState(() {
        _githubDashboardLoading = true;
      });
    }
    try {
      final payload = await _githubService.getDashboardRepositories();
      if (!mounted) return;
      setState(() {
        _githubDashboardRepositories = payload;
        _githubDashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _githubDashboardRepositories = null;
        _githubDashboardLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _unimportedGitHubRepositories() {
    final items = _githubDashboardRepositories?['unimported_repositories'];
    if (items is! List) return const <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  bool _shouldShowGitHubRepositorySection() {
    if (_githubDashboardLoading) return true;
    final payload = _githubDashboardRepositories;
    if (payload == null) return false;
    return payload['connected'] == true &&
        payload['token_valid'] == true &&
        _unimportedGitHubRepositories().isNotEmpty;
  }

  Future<void> _openGitHubRepositoryImport(
    Map<String, dynamic> repository,
  ) async {
    final installationId = (repository['installation_id'] as num?)?.toInt();
    if (installationId == null) return;
    final imported = await showAdaptiveModal<bool>(
      context: context,
      builder: (context) => ImportRepositoryDialog(
        repository: repository,
        installationId: installationId,
      ),
    );
    if (imported == true && mounted) {
      await Future.wait<void>([
        Provider.of<ProjectProvider>(context, listen: false).refresh(),
        _loadGitHubDashboardRepositories(),
      ]);
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
      appBar: D1VSimpleAppBar(
        enableBreathing: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _t('projects_search_hint', 'Search projects...'),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onChanged: (query) {
                  _performSearch(query);
                },
              )
            : Text(
                _t('dashboard', 'Dashboard'),
                style: LocaleFontHelper.localizedTitleStyle(
                  context,
                  Theme.of(context).textTheme.titleLarge,
                ),
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
          : Padding(
              padding: const EdgeInsets.only(bottom: 92),
              child: FloatingActionButton(
                tooltip: _t('create_project', 'Create Project'),
                onPressed: () {
                  CreateProjectDialog.show(context);
                },
                child: const Icon(Icons.add),
              ),
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
    final desktop = isDesktopLayout(context);

    // 如果有错误，显示错误提示
    if (projectProvider.error != null && projectProvider.projects.isEmpty) {
      return _buildErrorState(context, projectProvider);
    }

    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: desktop
          ? DesktopContentFrame(
              maxWidth: 1440,
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user != null) ...[
                          _buildWorkspaceStatusWidget(),
                          const SizedBox(height: 20),
                        ],
                        _buildStatsCards(stats, context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user != null)
                          FutureBuilder<PromptDailyActivity>(
                            future: _promptActivityFuture,
                            builder: (context, snapshot) {
                              if (_promptActivityFuture == null) {
                                return const SizedBox.shrink();
                              }
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const PromptActivitySkeleton();
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return CustomCard(
                                  glass: true,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      loc?.translate('failed_to_load') ??
                                          'Failed to load',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return PromptActivityHeatmap(
                                activity: snapshot.data!,
                                title: _t(
                                  'dashboard_activity_title',
                                  'Activity',
                                ),
                                subtitle: _t(
                                  'dashboard_activity_subtitle',
                                  'Recent prompt usage across your workspace.',
                                ),
                                headerTrailing:
                                    _buildPromptActivityHeaderTrailing(
                                      projectProvider,
                                    ),
                                onDayTap: (isoDate, count) {
                                  final message =
                                      _t(
                                            'dashboard_prompt_activity_day_message',
                                            '{count} prompts on {date}',
                                          )
                                          .replaceAll(
                                            '{count}',
                                            count.toString(),
                                          )
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
                        _buildPageSectionHeader(
                          context,
                          title:
                              _isSearching && _searchController.text.isNotEmpty
                              ? _t(
                                  'dashboard_search_results',
                                  'Search Results ({count})',
                                ).replaceAll(
                                  '{count}',
                                  _searchResults.length.toString(),
                                )
                              : _t('recent_projects', 'Recent Projects'),
                          subtitle: _t(
                            'dashboard_projects_subtitle',
                            'Continue from the most recently touched projects.',
                          ),
                          action: TextButton(
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
                        ),
                        const SizedBox(height: 8),
                        if (user == null)
                          LoginRequiredView(
                            variant: LoginRequiredVariant.full,
                            message:
                                loc?.translate(
                                  'login_required_dashboard_message',
                                ) ??
                                'Please login first.',
                            onAction: () => context.go('/login'),
                          )
                        else
                          _buildProjectList(
                            context,
                            projectProvider,
                            isSearchResults:
                                _isSearching &&
                                _searchController.text.isNotEmpty,
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ...[
                  _buildWorkspaceStatusWidget(),
                  const SizedBox(height: 20),
                ],
                _buildStatsCards(stats, context),
                const SizedBox(height: 24),
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
                              loc?.translate('failed_to_load') ??
                                  'Failed to load',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      }
                      return PromptActivityHeatmap(
                        activity: snapshot.data!,
                        title: _t('dashboard_activity_title', 'Activity'),
                        subtitle: _t(
                          'dashboard_activity_subtitle',
                          'Recent prompt usage across your workspace.',
                        ),
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
                _buildPageSectionHeader(
                  context,
                  title: _isSearching && _searchController.text.isNotEmpty
                      ? _t(
                          'dashboard_search_results',
                          'Search Results ({count})',
                        ).replaceAll(
                          '{count}',
                          _searchResults.length.toString(),
                        )
                      : _t('recent_projects', 'Recent Projects'),
                  subtitle: _t(
                    'dashboard_projects_subtitle',
                    'Continue from the most recently touched projects.',
                  ),
                  action: TextButton(
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
                const SizedBox(height: 48),
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
        await Future.wait<void>([
          projectProvider.refresh(),
          _loadGitHubDashboardRepositories(),
        ]);
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

  Widget _buildPageSectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 16), action],
      ],
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
    final showGitHubRepositories =
        !isSearchResults && _shouldShowGitHubRepositorySection();
    final children = <Widget>[];

    if (projects.isEmpty && !projectProvider.isLoading) {
      children.add(
        CustomCard(
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
        ),
      );
    } else {
      children.add(
        ListView.separated(
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
                onTap: () => context.push(buildProjectChatDetailRoute(project)),
                onChat: () =>
                    context.push(buildProjectChatDetailRoute(project)),
              ),
            );
          },
        ),
      );
    }

    if (showGitHubRepositories) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 20));
      }
      children.add(_buildGitHubAvailableRepositoriesSection(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  int _githubRepoMetric(Map<String, dynamic> repo, String key) {
    final value = repo[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Color _githubActionStatusColor(
    BuildContext context,
    Map<String, dynamic> repo,
  ) {
    final status = (repo['action_status'] ?? '').toString().trim();
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Theme.of(context).colorScheme.error;
      case 'in_progress':
        return Colors.amber;
      case 'neutral':
        return Theme.of(context).colorScheme.outline;
      default:
        return Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    }
  }

  Widget _buildGitHubInlineMetric(
    BuildContext context, {
    required IconData icon,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGitHubActionMetric(
    BuildContext context,
    Map<String, dynamic> repo,
  ) {
    final theme = Theme.of(context);
    final dotColor = _githubActionStatusColor(context, repo);
    final label = (repo['action_label'] ?? '').toString().trim();
    return Tooltip(
      message: label.isEmpty ? 'GitHub Actions' : label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.play_circle_outline_rounded,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubAvailableRepositoriesSection(BuildContext context) {
    final repos = _unimportedGitHubRepositories()
        .take(5)
        .toList(growable: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageSectionHeader(
          context,
          title: _t('create_project_github_import_title', 'GitHub Import'),
          subtitle: _t(
            'github_connect_description',
            'Connect your GitHub account to import repositories',
          ),
        ),
        const SizedBox(height: 8),
        if (_githubDashboardLoading)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 154,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 220,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.56,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(
                        4,
                        (metricIndex) => Padding(
                          padding: EdgeInsets.only(
                            right: metricIndex == 3 ? 0 : 12,
                          ),
                          child: Container(
                            width: 34,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.66),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: repos.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final repo = repos[index];
              final repoName = (repo['name'] ?? repo['full_name'] ?? '')
                  .toString()
                  .trim();
              final owner =
                  (repo['owner'] ?? repo['installation_account_login'] ?? '')
                      .toString()
                      .trim();
              final descriptionRaw = (repo['description'] ?? '')
                  .toString()
                  .trim();
              final description = descriptionRaw.isEmpty
                  ? _t(
                      'dashboard_projects_subtitle',
                      'Continue from the most recently touched projects.',
                    )
                  : descriptionRaw;
              final language = (repo['language'] ?? '').toString().trim();

              return CustomCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => unawaited(_openGitHubRepositoryImport(repo)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.download_for_offline_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      repoName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (owner.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '@$owner',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                children: [
                                  if (language.isNotEmpty)
                                    Text(
                                      language.toUpperCase(),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                    ),
                                  _buildGitHubInlineMetric(
                                    context,
                                    icon: Icons.star_border_rounded,
                                    value: _githubRepoMetric(
                                      repo,
                                      'stargazers_count',
                                    ).toString(),
                                  ),
                                  _buildGitHubInlineMetric(
                                    context,
                                    icon: Icons.call_split_rounded,
                                    value: _githubRepoMetric(
                                      repo,
                                      'forks_count',
                                    ).toString(),
                                  ),
                                  _buildGitHubInlineMetric(
                                    context,
                                    icon: Icons.adjust_outlined,
                                    value: _githubRepoMetric(
                                      repo,
                                      'issue_count',
                                    ).toString(),
                                  ),
                                  _buildGitHubInlineMetric(
                                    context,
                                    icon: Icons.merge_type_rounded,
                                    value: _githubRepoMetric(
                                      repo,
                                      'pull_request_count',
                                    ).toString(),
                                  ),
                                  _buildGitHubActionMetric(context, repo),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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
