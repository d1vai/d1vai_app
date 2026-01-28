import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/d1vai_service.dart';
import '../models/community_post.dart';
import '../widgets/search_field.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/post_card.dart';
import '../utils/error_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_required_dialog.dart';
import '../l10n/app_localizations.dart';

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
  Timer? _searchDebounce;
  int _loadRequestId = 0;

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  String _searchQuery = '';
  bool _isSearching = false;
  _CommunityFeedFilter _filter = _CommunityFeedFilter.all;
  final Set<String> _hiddenPostSlugs = <String>{};
  final Set<String> _blockedAuthorSlugs = <String>{};

  static const _prefsHiddenPostsKey = 'community_hidden_post_slugs';
  static const _prefsBlockedAuthorsKey = 'community_blocked_author_slugs';

  List<CommunityPost> _applyFilter(List<CommunityPost> list) {
    final base = list.where((p) {
      if (_hiddenPostSlugs.contains(p.slug)) return false;
      final authorSlug = (p.author?.slug ?? '').trim();
      if (authorSlug.isNotEmpty && _blockedAuthorSlugs.contains(authorSlug)) {
        return false;
      }
      return true;
    }).toList();

    switch (_filter) {
      case _CommunityFeedFilter.all:
        return base;
      case _CommunityFeedFilter.mine:
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uid = auth.user?.id;
        if (uid == null) return const <CommunityPost>[];
        return base.where((p) => p.userId == uid).toList();
      case _CommunityFeedFilter.drafts:
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uid = auth.user?.id;
        if (uid == null) return const <CommunityPost>[];
        return base
            .where((p) => p.userId == uid && (p.status ?? '') == 'draft')
            .toList();
    }
  }

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
    _loadModerationPrefs();
    _loadPosts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadModerationPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _hiddenPostSlugs
          ..clear()
          ..addAll(prefs.getStringList(_prefsHiddenPostsKey) ?? const <String>[]);
        _blockedAuthorSlugs
          ..clear()
          ..addAll(
            prefs.getStringList(_prefsBlockedAuthorsKey) ?? const <String>[],
          );
      });
    } catch (_) {
      // Best-effort only.
    }
  }

  void _handleHidePost(String slug) {
    if (slug.trim().isEmpty) return;
    setState(() {
      _hiddenPostSlugs.add(slug.trim());
      _posts.removeWhere((p) => p.slug == slug.trim());
    });
  }

  void _handleBlockAuthor(String authorSlug) {
    if (authorSlug.trim().isEmpty) return;
    setState(() {
      _blockedAuthorSlugs.add(authorSlug.trim());
      _posts.removeWhere((p) => (p.author?.slug ?? '').trim() == authorSlug.trim());
    });
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    final requestId = ++_loadRequestId;
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

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        if (refresh) {
          _posts = posts;
        } else {
          _posts.addAll(posts);
        }
        _isLoading = false;
        _hasMore = posts.length >= _limit;
        _offset += posts.length;
        _animationController.forward(from: 0);
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _error = humanizeError(e);
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

  void _scheduleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      unawaited(_loadPosts(refresh: true));
    });
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
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppBarSearchField(
                hintText: 'Search posts...',
                autofocus: true,
                onChanged: (value) {
                  _scheduleSearch(value);
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
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (!auth.isAuthenticated) {
                await showDialog<void>(
                  context: context,
                  builder: (context) => LoginRequiredDialog(
                    message:
                        loc?.translate('login_required_create_post_message') ??
                        'Please login first to create a post.',
                  ),
                );
                return;
              }
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final visiblePosts = _applyFilter(_posts);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
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

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: EasyRefresh(
            controller: _controller,
            header: const ClassicHeader(),
            footer: const ClassicFooter(),
            onRefresh: () async {
              await _loadPosts(refresh: true);
              if (!mounted) return;
              _controller.finishRefresh();
            },
            onLoad: () async {
              if (_hasMore) {
                await _loadPosts();
                if (!mounted) return;
                _controller.finishLoad(
                  _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
                );
              } else {
                if (!mounted) return;
                _controller.finishLoad(IndicatorResult.noMore);
              }
            },
            child: ListView.builder(
              itemCount: visiblePosts.isEmpty ? 1 : visiblePosts.length,
              itemBuilder: (context, index) {
                if (visiblePosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildFilteredEmptyCard(context),
                  );
                }

                final post = visiblePosts[index];
                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
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
                    onHidePost: _handleHidePost,
                    onBlockAuthor: _handleBlockAuthor,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuthed = auth.user != null;

    Future<void> setFilter(_CommunityFeedFilter next) async {
      if ((next == _CommunityFeedFilter.mine || next == _CommunityFeedFilter.drafts) &&
          !isAuthed) {
        await showDialog<void>(
          context: context,
          builder: (_) => const LoginRequiredDialog(),
        );
        return;
      }
      setState(() {
        _filter = next;
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _filter == _CommunityFeedFilter.all,
            onSelected: (_) => setFilter(_CommunityFeedFilter.all),
          ),
          ChoiceChip(
            label: Text(isAuthed ? 'My posts' : 'My posts (login)'),
            selected: _filter == _CommunityFeedFilter.mine,
            onSelected: (_) => setFilter(_CommunityFeedFilter.mine),
          ),
          ChoiceChip(
            label: Text(isAuthed ? 'My drafts' : 'My drafts (login)'),
            selected: _filter == _CommunityFeedFilter.drafts,
            onSelected: (_) => setFilter(_CommunityFeedFilter.drafts),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyCard(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        switch (_filter) {
          _CommunityFeedFilter.all => 'No posts.',
          _CommunityFeedFilter.mine => 'No posts created by you yet.',
          _CommunityFeedFilter.drafts => 'No drafts yet.',
        };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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

enum _CommunityFeedFilter { all, mine, drafts }
