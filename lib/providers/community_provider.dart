import 'package:flutter/material.dart';
import '../models/community.dart';

/// Community Provider - 管理社区页面状态
class CommunityProvider extends ChangeNotifier {
  // 数据状态
  List<CommunityPost> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;

  // 搜索状态
  String _searchQuery = '';
  String _sort = 'published_at';
  String _order = 'desc';

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

  void setSort(String sort) {
    _sort = sort;
    notifyListeners();
  }

  void setOrder(String order) {
    _order = order;
    notifyListeners();
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
      // 创建查询参数
      final query = CommunityPostsQuery(
        q: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _limit,
        offset: _currentOffset,
        sort: _sort,
        order: _order,
      );

      // 这里应该调用 API
      // 注意：当前使用模拟数据，实际使用时需要替换为真实 API 调用
      final response = await _fetchCommunityPostsMock(query);

      if (response.code == 0) {
        if (_currentOffset == 0) {
          _posts = response.data;
        } else {
          _posts.addAll(response.data);
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
  Future<CommunityPostsResponse> _fetchCommunityPostsMock(CommunityPostsQuery query) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 生成模拟数据
    final posts = <CommunityPost>[];
    final startIndex = query.offset;
    final endIndex = startIndex + query.limit;

    for (int i = startIndex; i < endIndex; i++) {
      posts.add(
        CommunityPost(
          id: i + 1,
          projectId: 'proj_${i + 1}',
          userId: 1000 + i,
          slug: 'awesome-project-$i',
          title: 'Amazing Project Title $i',
          summary: 'This is a sample description for an awesome project that showcases innovative features and cutting-edge technology. Check it out!',
          coverUrl: 'https://picsum.photos/seed/project$i/400/200',
          tags: ['Flutter', 'Mobile', 'Innovation'],
          status: 'published',
          publishedAt: DateTime.now().subtract(Duration(hours: i)),
          embedUrl: 'https://example.com/demo$i',
          author: Author(
            slug: 'user$i',
            email: 'user$i@example.com',
            picture: 'https://i.pravatar.cc/150?img=$i',
          ),
        ),
      );
    }

    return CommunityPostsResponse(
      code: 0,
      message: 'success',
      data: posts,
      total: 100, // 模拟总共 100 个帖子
    );
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
             post.summary.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
