import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/project.dart';
import '../widgets/create_project_dialog.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/search_field.dart';
import '../utils/error_utils.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          showDialog(
            context: context,
            builder: (context) => const CreateProjectDialog(),
          );
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

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProjectProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchField(
              hintText: 'Search projects...',
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

          // 项目列表
          Expanded(
            child: Consumer<ProjectProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.projects.isEmpty) {
                  return _buildShimmer();
                }

                if (provider.error != null &&
                    provider.error != _lastErrorShown) {
                  _lastErrorShown = provider.error;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final authExpired = isAuthExpiredText(provider.error!);
                    SnackBarHelper.showError(
                      context,
                      title: 'Sync failed',
                      message: provider.error!,
                      actionLabel: authExpired ? 'Re-login' : null,
                      onActionPressed: authExpired
                          ? () {
                              unawaited(_logoutAndGoLogin());
                            }
                          : null,
                    );
                  });
                }

                if (provider.error != null && provider.projects.isEmpty) {
                  final theme = Theme.of(context);
                  final authExpired = isAuthExpiredText(provider.error!);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                              child: const Text('Retry'),
                            ),
                            if (authExpired)
                              OutlinedButton(
                                onPressed: () {
                                  unawaited(_logoutAndGoLogin());
                                },
                                child: const Text('Re-login'),
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
                              ? 'No projects match your search'
                              : 'No projects found',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!hasSearchQuery) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    const CreateProjectDialog(),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Project'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        visibleProjects.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == visibleProjects.length) {
                        // 加载更多指示器
                        if (provider.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: _loadMore,
                                child: const Text('Load More'),
                              ),
                            ),
                          );
                        }
                      }

                      final project = visibleProjects[index];
                      return _buildProjectCard(project, context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CreateProjectDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 构建项目卡片
  Widget _buildProjectCard(UserProject project, BuildContext context) {
    return ProjectCardTile(
      project: project,
      updatedText: _formatTimeAgo(project.updatedAt),
      onTap: () => context.push('/projects/${project.id}'),
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
