import 'package:flutter/material.dart';
import '../models/project.dart';

/// Project Provider - 管理项目页面状态
class ProjectProvider extends ChangeNotifier {
  // 数据状态
  List<UserProject> _projects = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;

  // 搜索状态
  String _searchQuery = '';
  String _sort = 'updated_at';
  String _order = 'desc';
  String? _status;

  // 错误状态
  String? _error;

  // Getter
  List<UserProject> get projects => _projects;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  int get totalProjects => _projects.length;

  /// 重置状态
  void _reset() {
    _projects = [];
    _currentOffset = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  /// 设置搜索参数
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  void setSort(String sort) {
    _sort = sort;
    notifyListeners();
  }

  void setOrder(String order) {
    _order = order;
    notifyListeners();
  }

  void setStatus(String? status) {
    _status = status;
    notifyListeners();
  }

  /// 刷新数据
  Future<void> refresh() async {
    _reset();
    await loadProjects();
  }

  /// 加载更多数据
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await loadProjects();
  }

  /// 加载项目数据
  Future<void> loadProjects() async {
    if (_currentOffset == 0) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    notifyListeners();

    try {
      // 创建查询参数
      final query = ProjectsQuery(
        q: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _limit,
        offset: _currentOffset,
        sort: _sort,
        order: _order,
        status: _status,
      );

      // 调用 API 或使用模拟数据
      final response = await _fetchProjectsMock(query);

      if (response.code == 0) {
        if (_currentOffset == 0) {
          _projects = response.data;
        } else {
          _projects.addAll(response.data);
        }
        _currentOffset += response.data.length;
        _hasMore = response.data.length == _limit;
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 模拟 API 调用 - 实际使用时替换为真实 API
  Future<ProjectsResponse> _fetchProjectsMock(ProjectsQuery query) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 生成模拟数据
    final projects = <UserProject>[];
    final startIndex = query.offset ?? 0;
    final endIndex = startIndex + (query.limit ?? _limit);

    for (int i = startIndex; i < endIndex; i++) {
      projects.add(
        UserProject(
          id: 'proj_$i',
          projectName: 'My Awesome Project $i',
          projectDescription:
              'This is a sample description for project $i. It showcases innovative features and cutting-edge technology.',
          createdAt: DateTime.now()
              .subtract(Duration(days: i * 7))
              .toIso8601String(),
          updatedAt: DateTime.now()
              .subtract(Duration(days: i * 3))
              .toIso8601String(),
          userId: 1000,
          projectPort: 3000 + i,
          emoji: ['🚀', '💡', '🎨', '⚡', '🔥'][i % 5],
          latestPreviewUrl: 'https://picsum.photos/seed/project$i/400/250',
          tags: i % 3 == 0 ? ['Flutter', 'Mobile'] : ['Web', 'React'],
          status: i % 10 == 0 ? 'archived' : 'active',
        ),
      );
    }

    return ProjectsResponse(
      code: 0,
      message: 'success',
      data: projects,
      total: 50, // 模拟总共 50 个项目
    );
  }

  /// 获取项目的详细信息（根据 ID）
  UserProject? getProjectById(String id) {
    try {
      return _projects.firstWhere((project) => project.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 搜索项目
  List<UserProject> searchProjects(String query) {
    if (query.isEmpty) return _projects;
    return _projects.where((project) {
      return project.projectName.toLowerCase().contains(query.toLowerCase()) ||
          project.projectDescription.toLowerCase().contains(
            query.toLowerCase(),
          );
    }).toList();
  }

  /// 获取项目统计信息
  Map<String, int> getProjectStats() {
    int active = 0;
    int archived = 0;
    int draft = 0;

    for (final project in _projects) {
      switch (project.status) {
        case 'active':
          active++;
          break;
        case 'archived':
          archived++;
          break;
        case 'draft':
          draft++;
          break;
      }
    }

    return {
      'total': _projects.length,
      'active': active,
      'archived': archived,
      'draft': draft,
    };
  }
}
