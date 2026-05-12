import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../widgets/create_project_dialog.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/search_field.dart';
import '../utils/error_utils.dart';
import '../utils/desktop_layout.dart';
import '../core/auth_expiry_bus.dart';
import '../l10n/app_localizations.dart';
import 'projects/widgets/project_card_tile.dart';

class ProjectsScreen extends StatefulWidget {
  final bool openCreateOnStart;
  final String? initialSearchQuery;

  const ProjectsScreen({
    super.key,
    this.openCreateOnStart = false,
    this.initialSearchQuery,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Timer? _searchDebounce;
  String? _lastErrorShown;
  bool _didOpenCreate = false;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      final initialQuery = widget.initialSearchQuery?.trim() ?? '';
      if (initialQuery.isNotEmpty && provider.searchQuery.trim().isEmpty) {
        provider.setSearchQuery(initialQuery);
      }

      provider.loadProjects();

      if (widget.openCreateOnStart && !_didOpenCreate) {
        _didOpenCreate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          CreateProjectDialog.show(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final q = query.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      provider.setSearchQuery(q);
    });
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    await Provider.of<ProjectProvider>(context, listen: false).refresh();
  }

  /// 加载更多数据
  Future<void> _loadMore() async {
    await Provider.of<ProjectProvider>(context, listen: false).loadMore();
  }

  /// 处理搜索
  void _handleSearch(String query) {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    provider.setSearchQuery(query.trim());
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return Scaffold(
      appBar: AppBar(title: Text(_t('projects_title', 'Projects'))),
      body: Consumer<ProjectProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.projects.isEmpty) {
            return _buildShimmer();
          }

          if (provider.error != null && provider.error != _lastErrorShown) {
            _lastErrorShown = provider.error;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final authExpired = isAuthExpiredText(provider.error!);
              if (authExpired) {
                AuthExpiryBus.trigger(endpoint: '/api/projects');
                return;
              }
              SnackBarHelper.showError(
                context,
                title: _t('projects_sync_failed_title', 'Sync failed'),
                message: provider.error!,
              );
            });
          }

          final content = Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: SearchField(
                              hintText: _t(
                                'projects_search_hint',
                                'Search projects...',
                              ),
                              initialValue: provider.searchQuery,
                              onChanged: _onSearchChanged,
                              onSubmitted: _handleSearch,
                              onClear: () {
                                Provider.of<ProjectProvider>(
                                  context,
                                  listen: false,
                                ).setSearchQuery('');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: _buildProjectsDesktopSummary(provider),
                          ),
                        ],
                      )
                    : SearchField(
                        hintText: _t(
                          'projects_search_hint',
                          'Search projects...',
                        ),
                        initialValue: provider.searchQuery,
                        onChanged: _onSearchChanged,
                        onSubmitted: _handleSearch,
                        onClear: () {
                          Provider.of<ProjectProvider>(
                            context,
                            listen: false,
                          ).setSearchQuery('');
                        },
                      ),
              ),
              Expanded(child: _buildProjectsBody(provider, desktop)),
            ],
          );

          return desktop
              ? DesktopContentFrame(maxWidth: 1420, child: content)
              : content;
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _t('create_project', 'Create Project'),
        onPressed: () {
          CreateProjectDialog.show(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectsBody(ProjectProvider provider, bool desktop) {
    if (provider.error != null && provider.projects.isEmpty) {
      final theme = Theme.of(context);
      final authExpired = isAuthExpiredText(provider.error!);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              provider.error!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _refreshData,
                  child: Text(_t('retry', 'Retry')),
                ),
                if (authExpired)
                  OutlinedButton(
                    onPressed: () {
                      AuthExpiryBus.trigger(endpoint: '/api/projects');
                    },
                    child: Text(_t('projects_action_relogin', 'Re-login')),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final visibleProjects = provider.visibleProjects;
    if (visibleProjects.isEmpty) {
      final hasSearchQuery = provider.searchQuery.trim().isNotEmpty;
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearchQuery
                  ? _t(
                      'projects_empty_filtered',
                      'No projects match your search',
                    )
                  : _t('projects_empty', 'No projects found'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (!hasSearchQuery) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  CreateProjectDialog.show(context);
                },
                icon: const Icon(Icons.add),
                label: Text(_t('create_project', 'Create Project')),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: desktop
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 214,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: visibleProjects.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == visibleProjects.length) {
                  return Center(
                    child: provider.isLoadingMore
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _loadMore,
                            child: Text(
                              _t('projects_action_load_more', 'Load More'),
                            ),
                          ),
                  );
                }
                return _buildProjectCard(visibleProjects[index], context);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleProjects.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == visibleProjects.length) {
                  if (provider.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _loadMore,
                        child: Text(
                          _t('projects_action_load_more', 'Load More'),
                        ),
                      ),
                    ),
                  );
                }
                return _buildProjectCard(visibleProjects[index], context);
              },
            ),
    );
  }

  Widget _buildProjectsDesktopSummary(ProjectProvider provider) {
    final theme = Theme.of(context);
    final stats = provider.getProjectStats();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat('Total', stats['total'] ?? 0)),
          Expanded(child: _buildMiniStat('Active', stats['active'] ?? 0)),
          Expanded(child: _buildMiniStat('Archived', stats['archived'] ?? 0)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 构建项目卡片
  Widget _buildProjectCard(UserProject project, BuildContext context) {
    return ProjectCardTile(
      project: project,
      updatedText: _formatTimeAgo(project.updatedAt),
      onTap: () => context.push('/projects/${project.id}'),
      onChat: () => context.push('/projects/${project.id}/chat'),
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

  /// 构建骨架屏加载效果
  Widget _buildShimmer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.6,
                              height: 14,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
