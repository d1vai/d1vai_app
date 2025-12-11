import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:shimmer/shimmer.dart';
import '../services/d1vai_service.dart';
import '../models/community_post.dart';
import '../widgets/search_field.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/post_card.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late EasyRefreshController _controller;
  final D1vaiService _d1vaiService = D1vaiService();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadPosts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final posts = await _d1vaiService.getCommunityPosts(
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _posts = posts;
        } else {
          _posts.addAll(posts);
        }
        _isLoading = false;
        _hasMore = posts.length >= _limit;
        _offset += posts.length;
        if (!refresh && posts.isNotEmpty) {
          _animationController.forward(
            from: 0.0,
          ); // Reset for new page or just forward?
          // Actually for pagination we might want to just animate new items, but for now let's just forward if it's the first load or refresh.
          // Simpler: just forward.
        }
        if (refresh || _offset == posts.length) {
          _animationController.forward(from: 0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 执行搜索
  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
    await _loadPosts(refresh: true);
  }

  /// 切换搜索状态
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
    if (!_isSearching) {
      _searchController.clear();
      _performSearch('');
    }
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppBarSearchField(
                hintText: 'Search posts...',
                autofocus: true,
                onChanged: (value) {
                  _performSearch(value);
                },
                onClear: _clearSearch,
              )
            : const Text('Community'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              );

              if (result == true) {
                _controller.callRefresh();
              }
            },
          ),
        ],
      ),
      body: _isSearching && _searchQuery.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Searching for "$_searchQuery"...',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Press the search icon to start',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : EasyRefresh(
              controller: _controller,
              onRefresh: () async {
                await _loadPosts(refresh: true);
                if (!mounted) return;
                _controller.finishRefresh();
              },
              onLoad: () async {
                await _loadPosts();
                if (!mounted) return;
                _controller.finishLoad(
                  _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
                );
              },
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return _buildShimmer();
    }

    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Failed to load posts',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _loadPosts(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.forum_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results found' : 'No posts yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Be the first to share something!',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return EasyRefresh(
      controller: _controller,
      header: const ClassicHeader(),
      footer: const ClassicFooter(),
      onRefresh: () async {
        await _loadPosts(refresh: true);
        _controller.finishRefresh();
      },
      onLoad: () async {
        if (_hasMore) {
          await _loadPosts();
          _controller.finishLoad(
            _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
          );
        } else {
          _controller.finishLoad(IndicatorResult.noMore);
        }
      },
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              // To avoid long delays on long lists, cap the delay or use modulo
              final safeIndex = index > 10 ? 10 : index;
              final start = safeIndex * 0.1;
              final end = (start + 0.4).clamp(0.0, 1.0);

              final animation = CurvedAnimation(
                parent: _animationController,
                curve: Interval(start, end, curve: Curves.easeOut),
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
            child: PostCard(
              post: post,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
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
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户信息行
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 14,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 帖子标题
                  Container(
                    width: double.infinity,
                    height: 18,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 帖子内容
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 封面图片占位
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 操作按钮行
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
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
