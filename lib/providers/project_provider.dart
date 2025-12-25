import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/d1vai_service.dart';
import '../utils/error_utils.dart';

/// Project Provider - 管理项目页面状态
class ProjectProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();

  // 数据状态
  List<UserProject> _projects = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  final int _pageSize = 20;
  int _visibleLimit = 20;

  // 搜索状态
  String _searchQuery = '';

  // 状态过滤
  String? _statusFilter;

  // 错误状态
  String? _error;

  // Getter
  List<UserProject> get projects => _projects;
  String get searchQuery => _searchQuery;
  String? get statusFilter => _statusFilter;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isInitialLoading => _isLoading && _projects.isEmpty;
  String? get error => _error;
  int get totalProjects => _projects.length;

  List<UserProject> get filteredProjects => _applyFilters();

  List<UserProject> get visibleProjects {
    final filtered = _applyFilters();
    final limit = _visibleLimit.clamp(0, filtered.length);
    return filtered.take(limit).toList();
  }

  bool get hasMore => _visibleLimit < _applyFilters().length;

  void _resetPaging() {
    _visibleLimit = _pageSize;
  }

  /// 重置状态
  void _reset() {
    _projects = [];
    _resetPaging();
    _error = null;
    notifyListeners();
  }

  /// 设置搜索参数
  void setSearchQuery(String query) {
    _searchQuery = query;
    _resetPaging();
    notifyListeners();
  }

  /// 设置状态过滤
  void setStatus(String? status) {
    _statusFilter = status;
    _resetPaging();
    notifyListeners();
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadProjects(forceRefresh: true);
  }

  /// 加载更多数据
  Future<void> loadMore() async {
    if (!hasMore || _isLoading || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    // 本地分页：只增加展示数量，不触发网络请求
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _visibleLimit += _pageSize;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// 加载项目数据
  Future<void> loadProjects({bool forceRefresh = false}) async {
    final shouldShowBlockingLoading = _projects.isEmpty;
    if (shouldShowBlockingLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      // 非阻塞刷新：保留当前列表，避免 UI 闪烁
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // 调用真实 API 获取项目列表
      final List<UserProject> newProjects = await _d1vaiService.getUserProjects(
        forceRefresh: forceRefresh,
      );

      // 始终用最新结果覆盖本地列表，避免重复追加。
      _projects = List<UserProject>.from(newProjects)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _resetPaging();
    } catch (e) {
      _error = humanizeError(e);
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
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

  List<UserProject> _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();
    final status = _statusFilter?.trim();

    Iterable<UserProject> list = _projects;

    if (status != null && status.isNotEmpty) {
      list = list.where((p) => p.status == status);
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        final name = p.projectName.toLowerCase();
        final desc = p.projectDescription.toLowerCase();
        final tags = p.tags.join(' ').toLowerCase();
        return name.contains(q) || desc.contains(q) || tags.contains(q);
      });
    }

    return list.toList();
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
