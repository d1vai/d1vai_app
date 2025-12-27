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
import '../utils/error_utils.dart';
import 'projects/widgets/project_card_tile.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _selectedFilter = 'all';
  String? _lastErrorShown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      // Restore last state (useful when navigating back from detail pages).
      if (provider.searchQuery.trim().isNotEmpty &&
          _searchController.text.trim().isEmpty) {
        _searchController.text = provider.searchQuery;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      }
      final status = provider.statusFilter;
      final nextSelected =
          (status == null || status.isEmpty) ? 'all' : status;
      if (mounted && nextSelected != _selectedFilter) {
        setState(() {
          _selectedFilter = nextSelected;
        });
      }
      provider.loadProjects();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// 搜索内容变化处理
  void _onSearchChanged() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      provider.setSearchQuery(query);
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
    provider.setSearchQuery(query);
  }

  /// 处理过滤
  void _handleFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    provider.setStatus(filter == 'all' ? null : filter);
  }

  /// 处理登出
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('您确定要登出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认登出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 清除缓存
      await Provider.of<AuthProvider>(context, listen: false).logout();
      // 跳转到登录页面（替换当前页面，不保留返回栈）
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('登出'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search projects...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                // 实时搜索通过 _onSearchChanged 监听器处理
              },
              onSubmitted: _handleSearch,
            ),
          ),

          // 过滤器标签
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', 'all', _selectedFilter, _handleFilter),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Active',
                  'active',
                  _selectedFilter,
                  _handleFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Archived',
                  'archived',
                  _selectedFilter,
                  _handleFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Draft',
                  'draft',
                  _selectedFilter,
                  _handleFilter,
                ),
              ],
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
                  final hasSearchQuery =
                      _searchController.text.trim().isNotEmpty ||
                      provider.searchQuery.trim().isNotEmpty;
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

  /// 构建过滤标签
  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected,
  ) {
    final isSelected = selectedValue == value;
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onSelected(value),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
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
