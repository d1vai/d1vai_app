import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../services/d1vai_service.dart';

/// Community Provider - 管理社区页面状态
class CommunityProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();

  // 数据状态
  List<CommunityPost> _posts = [];
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
  List<CommunityPost> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  int get totalPosts => _posts.length;

  /// 重置状态
  void _reset() {
    _posts = [];
    _currentOffset = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  /// 设置搜索参数
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  /// 刷新数据
  Future<void> refresh() async {
    _reset();
    await loadPosts();
  }

  /// 加载更多数据
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await loadPosts();
  }

  /// 加载帖子数据
  Future<void> loadPosts() async {
    if (_currentOffset == 0) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    notifyListeners();

    try {
      // 调用真实 API 获取社区帖子
      final List<CommunityPost> newPosts = await _d1vaiService.getCommunityPosts(
        limit: _limit,
        offset: _currentOffset,
      );

      if (_currentOffset == 0) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }
      _currentOffset += newPosts.length;
      _hasMore = newPosts.length == _limit;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 获取帖子的详细信息（根据 ID）
  CommunityPost? getPostById(int id) {
    try {
      return _posts.firstWhere((post) => post.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 搜索帖子
  List<CommunityPost> searchPosts(String query) {
    if (query.isEmpty) return _posts;
    return _posts.where((post) {
      return post.title.toLowerCase().contains(query.toLowerCase()) ||
          (post.content?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }
}
