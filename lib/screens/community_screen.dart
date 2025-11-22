import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../services/d1vai_service.dart';
import '../models/community_post.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late EasyRefreshController _controller;
  final D1vaiService _d1vaiService = D1vaiService();

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    _loadPosts();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return timestamp;
    }
  }

  String _getEmailPrefix(String? email) {
    if (email == null || email.isEmpty) return '';
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email;
    return email.substring(0, atIndex);
  }

  String _getAuthorDisplayName(CommunityPost post) {
    if (post.author?.slug != null && post.author!.slug!.isNotEmpty) {
      return post.author!.slug!;
    }
    if (post.author?.email != null && post.author!.email!.isNotEmpty) {
      final prefix = _getEmailPrefix(post.author!.email);
      return prefix.isNotEmpty ? prefix : 'Anonymous';
    }
    return 'Anonymous';
  }

  Future<void> _handleSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
    await _loadPosts(refresh: true);
  }

  Future<void> _clearSearch() async {
    await _handleSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create post feature coming soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: _handleSearch,
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
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
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
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
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post detail feature coming soon'),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: post.author?.picture != null
                        ? NetworkImage(post.author!.picture!)
                        : null,
                    child: (post.author?.picture == null)
                        ? Text(
                            _getAuthorDisplayName(post).isNotEmpty
                                ? _getAuthorDisplayName(post)[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getAuthorDisplayName(post),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (post.author?.email != null && post.author!.email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${_getEmailPrefix(post.author!.email)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        Text(
                          _formatTime(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.share),
                                title: const Text('Share'),
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Share feature coming soon'),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.flag, color: Colors.orange),
                                title: const Text('Report'),
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Report feature coming soon'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cover image (like d1vai frontend)
              if (post.coverUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.coverUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Post title
              if (post.title.isNotEmpty) ...[
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Post summary or content
              if (post.summary != null && post.summary!.isNotEmpty) ...[
                Text(
                  post.summary!,
                  style: TextStyle(color: Colors.grey.shade700),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (post.content != null && post.content!.isNotEmpty) ...[
                Text(
                  post.content!,
                  style: TextStyle(color: Colors.grey.shade700),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              // Interaction row
              Row(
                children: [
                  Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: post.isLiked ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建骨架屏加载效果
  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
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
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 60,
                              height: 12,
                              color: Colors.white,
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
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),

                  // 帖子内容
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),

                  // 封面图片占位
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 20,
                        color: Colors.white,
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
