import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../models/community_component.dart';
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../services/d1vai_service.dart';
import '../utils/desktop_layout.dart';
import '../utils/error_utils.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/post_card.dart';
import '../widgets/search_field.dart';
import 'community_component_preview_screen.dart';
import 'post_detail_screen.dart';

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
  List<CommunityComponent> _components = [];
  bool _isLoading = true;
  String? _error;
  int _offset = 0;
  int _componentOffset = 0;
  final int _limit = 20;
  final int _componentLimit = 12;
  bool _hasMore = true;
  bool _hasMoreComponents = true;
  String _searchQuery = '';
  bool _isSearching = false;
  _CommunityFeedFilter _filter = _CommunityFeedFilter.all;
  _CommunityView _view = _CommunityView.posts;
  final Set<String> _hiddenPostSlugs = <String>{};
  final Set<String> _blockedAuthorSlugs = <String>{};

  static const _prefsHiddenPostsKey = 'community_hidden_post_slugs';
  static const _prefsBlockedAuthorsKey = 'community_blocked_author_slugs';

  void _finishRefreshNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.finishRefresh();
    });
  }

  void _finishLoadNextFrame(IndicatorResult result) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.finishLoad(result);
    });
  }

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
          ..addAll(
            prefs.getStringList(_prefsHiddenPostsKey) ?? const <String>[],
          );
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
      _posts.removeWhere(
        (p) => (p.author?.slug ?? '').trim() == authorSlug.trim(),
      );
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

  Future<void> _loadComponents({bool refresh = false}) async {
    final requestId = ++_loadRequestId;
    if (refresh) {
      _componentOffset = 0;
      _hasMoreComponents = true;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final components = await _d1vaiService.getCommunityComponents(
        limit: _componentLimit,
        offset: _componentOffset,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        if (refresh) {
          _components = components;
        } else {
          _components.addAll(components);
        }
        _isLoading = false;
        _hasMoreComponents = components.length >= _componentLimit;
        _componentOffset += components.length;
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

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
    if (_view == _CommunityView.posts) {
      await _loadPosts(refresh: true);
    } else {
      await _loadComponents(refresh: true);
    }
  }

  void _scheduleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      unawaited(
        _view == _CommunityView.posts
            ? _loadPosts(refresh: true)
            : _loadComponents(refresh: true),
      );
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
    if (!_isSearching) {
      _searchController.clear();
      _performSearch('');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppBarSearchField(
                hintText: 'Search posts...',
                autofocus: true,
                onChanged: _scheduleSearch,
                onClear: _clearSearch,
              )
            : const Text('Community'),
        actions: [
          IconButton(
            tooltip: _view == _CommunityView.posts
                ? 'Show components'
                : 'Show posts',
            icon: Icon(
              _view == _CommunityView.posts
                  ? Icons.widgets_outlined
                  : Icons.forum_outlined,
            ),
            onPressed: () {
              final next = _view == _CommunityView.posts
                  ? _CommunityView.components
                  : _CommunityView.posts;
              setState(() {
                _view = next;
              });
              unawaited(
                next == _CommunityView.posts
                    ? _loadPosts(refresh: true)
                    : _loadComponents(refresh: true),
              );
            },
          ),
          IconButton(
            tooltip: _isSearching ? 'Close search' : 'Search posts',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final visiblePosts = _applyFilter(_posts);
    final desktop = isDesktopLayout(context);
    final isPostsView = _view == _CommunityView.posts;
    final hasEmptyState = isPostsView ? _posts.isEmpty : _components.isEmpty;

    if (_isLoading && hasEmptyState) {
      return _buildShimmer();
    }

    if (_error != null && hasEmptyState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isPostsView ? 'Failed to load posts' : 'Failed to load components',
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
              onPressed: () => isPostsView
                  ? _loadPosts(refresh: true)
                  : _loadComponents(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (hasEmptyState) {
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
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : isPostsView
                      ? 'No posts yet'
                      : 'No components yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : isPostsView
                      ? 'Be the first to share something!'
                      : 'Browse public reusable components.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final feed = EasyRefresh(
      controller: _controller,
      header: const ClassicHeader(),
      footer: const ClassicFooter(),
      onRefresh: () async {
        await _loadPosts(refresh: true);
        if (!mounted) return;
        _finishRefreshNextFrame();
      },
      onLoad: () async {
        final hasMore = isPostsView ? _hasMore : _hasMoreComponents;
        if (hasMore) {
          if (isPostsView) {
            await _loadPosts();
          } else {
            await _loadComponents();
          }
          if (!mounted) return;
          _finishLoadNextFrame(
            (isPostsView ? _hasMore : _hasMoreComponents)
                ? IndicatorResult.success
                : IndicatorResult.noMore,
          );
        } else {
          if (!mounted) return;
          _finishLoadNextFrame(IndicatorResult.noMore);
        }
      },
      child: desktop
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisExtent: 238,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: isPostsView
                  ? (visiblePosts.isEmpty ? 1 : visiblePosts.length)
                  : (_components.isEmpty ? 1 : _components.length),
              itemBuilder: (context, index) {
                if (isPostsView && visiblePosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: _buildFilteredEmptyCard(context),
                  );
                }
                if (isPostsView) {
                  return _buildAnimatedPostCard(visiblePosts[index], index);
                }
                if (_components.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: _buildFilteredEmptyCard(context),
                  );
                }
                return _buildAnimatedComponentCard(_components[index], index);
              },
            )
          : ListView.builder(
              itemCount: isPostsView
                  ? (visiblePosts.isEmpty ? 1 : visiblePosts.length)
                  : (_components.isEmpty ? 1 : _components.length),
              itemBuilder: (context, index) {
                if (isPostsView && visiblePosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildFilteredEmptyCard(context),
                  );
                }
                if (isPostsView) {
                  return _buildAnimatedPostCard(visiblePosts[index], index);
                }
                if (_components.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildFilteredEmptyCard(context),
                  );
                }
                return _buildAnimatedComponentCard(_components[index], index);
              },
            ),
    );

    if (!desktop) {
      return Column(
        children: [
          _buildFilterBar(),
          Expanded(child: feed),
        ],
      );
    }

    return DesktopContentFrame(
      maxWidth: 1440,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _buildFilterBar(),
          ),
          Expanded(child: feed),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuthed = auth.user != null;

    Future<void> setFilter(_CommunityFeedFilter next) async {
      if (next == _CommunityFeedFilter.mine && !isAuthed) {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommunityViewTabs(
          selectedView: _view,
          onSelected: (next) {
            if (_view == next) return;
            setState(() {
              _view = next;
            });
            unawaited(
              next == _CommunityView.posts
                  ? _loadPosts(refresh: true)
                  : _loadComponents(refresh: true),
            );
          },
        ),
        const SizedBox(height: 10),
        if (_view == _CommunityView.posts)
          _CommunityFilterTabs(
            selectedFilter: _filter,
            isAuthed: isAuthed,
            onSelected: setFilter,
          ),
      ],
    );
  }

  Widget _buildFilteredEmptyCard(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (_filter) {
      _CommunityFeedFilter.all => 'No posts.',
      _CommunityFeedFilter.mine => 'No posts created by you yet.',
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

  Widget _buildAnimatedPostCard(CommunityPost post, int index) {
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
  }

  Widget _buildAnimatedComponentCard(CommunityComponent component, int index) {
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
      child: _CommunityComponentCard(
        component: component,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityComponentPreviewScreen(
                slug: component.slug,
                title: component.title,
              ),
            ),
          );
        },
        onToggleLike: () => _toggleComponentLike(component),
      ),
    );
  }

  Future<void> _toggleComponentLike(CommunityComponent component) async {
    final index = _components.indexWhere((item) => item.id == component.id);
    if (index < 0) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      await showDialog<void>(
        context: context,
        builder: (_) => const LoginRequiredDialog(),
      );
      return;
    }
    final previous = _components[index];
    setState(() {
      _components[index] = previous.copyWith(
        isLiked: !previous.isLiked,
        likeCount:
            (previous.likeCount + (previous.isLiked ? -1 : 1)).clamp(0, 1 << 30),
      );
    });
    try {
      final result = await _d1vaiService.toggleCommunityComponentLike(
        component.id,
      );
      if (!mounted) return;
      setState(() {
        _components[index] = _components[index].copyWith(
          isLiked: result['liked'] == true,
          likeCount: (result['like_count'] as num?)?.toInt() ??
              _components[index].likeCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _components[index] = previous;
      });
    }
  }

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
                  Container(
                    width: double.infinity,
                    height: 18,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
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

enum _CommunityFeedFilter { all, mine }

enum _CommunityView { posts, components }

class _CommunityViewTabs extends StatelessWidget {
  final _CommunityView selectedView;
  final ValueChanged<_CommunityView> onSelected;

  const _CommunityViewTabs({
    required this.selectedView,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CommunityViewTabButton(
              label: 'Posts',
              selected: selectedView == _CommunityView.posts,
              onTap: () => onSelected(_CommunityView.posts),
            ),
          ),
          Expanded(
            child: _CommunityViewTabButton(
              label: 'Components',
              selected: selectedView == _CommunityView.components,
              onTap: () => onSelected(_CommunityView.components),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityViewTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CommunityViewTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? colorScheme.primary.withValues(alpha: 0.12) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CommunityComponentCard extends StatelessWidget {
  final CommunityComponent component;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  const _CommunityComponentCard({
    required this.component,
    required this.onTap,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: component.previewImageUrl?.isNotEmpty == true
                  ? Image.network(
                      component.previewImageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x3322D3EE),
                            Color(0x331D4ED8),
                            Color(0x33C026D3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          component.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleLike,
                        icon: Icon(
                          component.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: component.isLiked ? Colors.red : null,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    component.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        component.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${component.likeCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFilterTabs extends StatelessWidget {
  final _CommunityFeedFilter selectedFilter;
  final bool isAuthed;
  final ValueChanged<_CommunityFeedFilter> onSelected;

  const _CommunityFilterTabs({
    required this.selectedFilter,
    required this.isAuthed,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tabs = [
      (
        filter: _CommunityFeedFilter.all,
        label: 'All',
        icon: PhosphorIcons.squaresFour(),
      ),
      (
        filter: _CommunityFeedFilter.mine,
        label: 'My posts',
        icon: PhosphorIcons.notePencil(),
      ),
    ];

    final shellColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
      colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.88 : 0.96,
      ),
    );
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.48 : 0.72,
    );

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: isDark ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _CommunityFilterTabButton(
                label: tab.label,
                icon: tab.icon,
                selected: tab.filter == selectedFilter,
                onTap: () => onSelected(tab.filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommunityFilterTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CommunityFilterTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: isDark ? 0.86 : 0.92);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.14),
                    colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.transparent,
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.34 : 0.16)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.14 : 0.08,
                    ),
                    blurRadius: isDark ? 16 : 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 108;
                  final iconSize = compact ? 14.0 : 16.0;
                  final spacing = compact ? 4.0 : 6.0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: iconSize, color: foregroundColor),
                      SizedBox(width: spacing),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: foregroundColor,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              letterSpacing: compact ? -0.15 : 0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
