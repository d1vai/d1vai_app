import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../widgets/create_project_dialog.dart';
import '../widgets/card.dart';
import '../core/theme/app_colors.dart';
import '../utils/error_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<UserProject> _searchResults = [];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 加载项目数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 加载数据
  Future<void> _loadData() async {
    await Provider.of<ProjectProvider>(context, listen: false).loadProjects();
    if (mounted) {
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search projects...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (query) {
                  _performSearch(query);
                },
              )
            : const Text('Dashboard'),
        actions: [
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
      body: projectProvider.isInitialLoading
          ? _buildShimmer()
          : _buildContent(user, context, projectProvider),
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

  Widget _buildShimmer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
                    Container(
                      width: double.infinity,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
                    Container(
                      width: 40.0,
                      height: 8.0,
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
        ),
      ),
    );
  }

  Widget _buildContent(
    User? user,
    BuildContext context,
    ProjectProvider projectProvider,
  ) {
    final stats = projectProvider.getProjectStats();

    // 如果有错误，显示错误提示
    if (projectProvider.error != null && projectProvider.projects.isEmpty) {
      return _buildErrorState(context, projectProvider);
    }

    return RefreshIndicator(
      onRefresh: () async => await projectProvider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.email ?? "User"}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // 项目统计卡片
            _buildStatsCards(stats, context),
            const SizedBox(height: 24),

            // 活动图表
            _buildAnalyticsChart(context, stats),
            const SizedBox(height: 24),

            // 最近项目
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isSearching && _searchController.text.isNotEmpty
                      ? 'Search Results (${_searchResults.length})'
                      : 'Recent Projects',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.push('/projects'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProjectList(
              context,
              projectProvider,
              isSearchResults:
                  _isSearching && _searchController.text.isNotEmpty,
            ),
            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }

  /// 构建项目统计卡片
  Widget _buildStatsCards(Map<String, int> stats, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            stats['total'].toString(),
            Icons.folder,
            AppColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active',
            stats['active'].toString(),
            Icons.play_circle_outline,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Archived',
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

  Widget _buildAnalyticsChart(BuildContext context, Map<String, int> stats) {
    return CustomCard(
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < titles.length) {
                            return Text(
                              titles[value.toInt()],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: (stats['total'] ?? 5).toDouble() + 2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateActivitySpots(stats['total'] ?? 0),
                      isCurved: true,
                      color: AppColors.primaryBrand,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryBrand.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(
    BuildContext context,
    ProjectProvider projectProvider, {
    bool isSearchResults = false,
  }) {
    final theme = Theme.of(context);
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
                'No projects yet',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first project to get started',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
          child: CustomCard(
            child: InkWell(
              onTap: () => context.push('/projects/${project.id}'),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        project.emoji ?? '🚀',
                        style: const TextStyle(fontSize: 36),
                        textAlign: TextAlign.center,
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
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project.projectDescription,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: project.status == 'active'
                                    ? AppColors.success
                                    : project.status == 'archived'
                                    ? AppColors.warning
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                project.status,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(project.updatedAt),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  /// 生成基于项目数量的活动图表数据
  List<FlSpot> _generateActivitySpots(int totalProjects) {
    // 基于项目总数生成模拟的活动数据，但确保使用真实项目数量
    final baseValue = (totalProjects * 0.8).clamp(1.0, 10.0);

    return List.generate(7, (index) {
      final variance = (index % 2 == 0) ? 0.5 : -0.3;
      final value = (baseValue + variance + index * 0.1).clamp(0.5, 15.0);
      return FlSpot(index.toDouble(), value);
    });
  }

  /// 构建错误状态
  Widget _buildErrorState(
    BuildContext context,
    ProjectProvider projectProvider,
  ) {
    final errText = projectProvider.error ?? 'Unknown error';
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
              'Failed to load projects',
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
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (authExpired)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Re-login'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
