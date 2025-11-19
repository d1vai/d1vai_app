import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/d1vai_service.dart';

/// Project Provider - 管理项目页面状态
class ProjectProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();

  // 数据状态
  List<UserProject> _projects = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;

  // 搜索状态
  String _searchQuery = '';

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

  /// 设置状态过滤
  void setStatus(String? status) {
    // TODO: 未来将支持项目状态过滤
    // 当前 API 不支持此功能
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
      // 调用真实 API 获取项目列表
      final List<UserProject> newProjects = await _d1vaiService.getUserProjects();

      if (_currentOffset == 0) {
        _projects = newProjects;
      } else {
        _projects.addAll(newProjects);
      }
      _currentOffset += newProjects.length;
      _hasMore = newProjects.length == _limit;
    } catch (e) {
      _error = e.toString();
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
