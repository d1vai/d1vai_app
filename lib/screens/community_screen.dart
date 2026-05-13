import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/locale_font_helper.dart';
import '../l10n/app_localizations.dart';
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
  _CommunityTab _tab = _CommunityTab.posts;
  final Set<String> _hiddenPostSlugs = <String>{};
  final Set<String> _blockedAuthorSlugs = <String>{};

  static const _prefsHiddenPostsKey = 'community_hidden_post_slugs';
  static const _prefsBlockedAuthorsKey = 'community_blocked_author_slugs';

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

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

  List<CommunityPost> _visiblePosts(List<CommunityPost> list) {
    final base = list.where((p) {
      if (_hiddenPostSlugs.contains(p.slug)) return false;
      final authorSlug = (p.author?.slug ?? '').trim();
      if (authorSlug.isNotEmpty && _blockedAuthorSlugs.contains(authorSlug)) {
        return false;
      }
      return true;
    }).toList();

    if (_tab == _CommunityTab.myPosts) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.user?.id;
      if (uid == null) return const <CommunityPost>[];
      return base.where((p) => p.userId == uid).toList();
    }
    return base;
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
    if (_isPostsTab) {
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
        _isPostsTab
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
    final theme = Theme.of(context);
    final isPostsView = _isPostsTab;
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppBarSearchField(
                hintText: isPostsView
                    ? _t('community_search_hint', 'Search posts...')
                    : _t(
                        'community_search_components_hint',
                        'Search components...',
                      ),
                autofocus: true,
                onChanged: _scheduleSearch,
                onClear: _clearSearch,
              )
            : Text(
                _t('community', 'Community'),
                style: LocaleFontHelper.localizedTitleStyle(
                  context,
                  theme.textTheme.titleLarge,
                ),
              ),
        actions: [
          IconButton(
            tooltip: _isSearching
                ? _t('community_close_search', 'Close search')
                : isPostsView
                ? _t('community_search_posts', 'Search posts')
                : _t(
                    'community_search_components',
                    'Search components',
                  ),
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final visiblePosts = _visiblePosts(_posts);
    final desktop = isDesktopLayout(context);
    final isPostsView = _isPostsTab;
    final hasEmptyState = isPostsView
        ? visiblePosts.isEmpty
        : _components.isEmpty;

    Widget content;

    if (_isLoading && hasEmptyState) {
      content = _buildShimmer();
    } else if (_error != null && hasEmptyState) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isPostsView
                  ? _t('failed_to_load_posts', 'Failed to load posts')
                  : _t(
                      'community_failed_to_load_components',
                      'Failed to load components',
                    ),
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
              child: Text(_t('retry', 'Retry')),
            ),
          ],
        ),
      );
    } else if (hasEmptyState) {
      content = Center(
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
                  ? _t('community_no_results', 'No results found')
                  : isPostsView
                  ? _t('no_posts_yet', 'No posts yet')
                  : _t('community_no_components_yet', 'No components yet'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? _t(
                      'community_try_different_search',
                      'Try a different search term',
                    )
                  : isPostsView
                  ? (_tab == _CommunityTab.myPosts
                        ? _t(
                            'community_empty_my_posts_sentence',
                            'You have not published any posts yet.',
                          )
                        : _t(
                            'be_first_to_share',
                            'Be the first to share something!',
                          ))
                  : _t(
                      'community_browse_components',
                      'Browse public reusable components.',
                    ),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    } else {
      content = EasyRefresh(
        controller: _controller,
        header: const ClassicHeader(),
        footer: const ClassicFooter(),
        onRefresh: () async {
          if (isPostsView) {
            await _loadPosts(refresh: true);
          } else {
            await _loadComponents(refresh: true);
          }
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
    }

    if (!desktop) {
      return Column(
        children: [
          _buildFilterBar(),
          Expanded(child: content),
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
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuthed = auth.user != null;

    Future<void> setTab(_CommunityTab next) async {
      if (next == _CommunityTab.myPosts && !isAuthed) {
        await showDialog<void>(
          context: context,
          builder: (_) => const LoginRequiredDialog(),
        );
        return;
      }
      if (_tab == next) return;
      setState(() {
        _tab = next;
      });
      unawaited(
        next == _CommunityTab.components
            ? _loadComponents(refresh: true)
            : _loadPosts(refresh: true),
      );
    }

    return _CommunityTabs(selectedTab: _tab, onSelected: setTab);
  }

  Widget _buildFilteredEmptyCard(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (_tab) {
      _CommunityTab.posts => _t('community_empty_all', 'No posts.'),
      _CommunityTab.myPosts => _t(
        'community_empty_mine',
        'No posts created by you yet.',
      ),
      _CommunityTab.components => _t(
        'community_empty_components',
        'No components.',
      ),
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
        likeCount: (previous.likeCount + (previous.isLiked ? -1 : 1)).clamp(
          0,
          1 << 30,
        ),
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
          likeCount:
              (result['like_count'] as num?)?.toInt() ??
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

enum _CommunityTab { posts, components, myPosts }

extension on _CommunityScreenState {
  bool get _isPostsTab =>
      _tab == _CommunityTab.posts || _tab == _CommunityTab.myPosts;
}

class _CommunityTabs extends StatelessWidget {
  final _CommunityTab selectedTab;
  final ValueChanged<_CommunityTab> onSelected;

  const _CommunityTabs({required this.selectedTab, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String t(String key, String fallback) {
      final value = AppLocalizations.of(context)?.translate(key);
      if (value == null || value == key) return fallback;
      return value;
    }
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
            child: _CommunityTabButton(
              label: t('community_tab_posts', 'Posts'),
              selected: selectedTab == _CommunityTab.posts,
              onTap: () => onSelected(_CommunityTab.posts),
            ),
          ),
          Expanded(
            child: _CommunityTabButton(
              label: t('community_tab_components', 'Components'),
              selected: selectedTab == _CommunityTab.components,
              onTap: () => onSelected(_CommunityTab.components),
            ),
          ),
          Expanded(
            child: _CommunityTabButton(
              label: t('community_tab_my_posts', 'My posts'),
              selected: selectedTab == _CommunityTab.myPosts,
              onTap: () => onSelected(_CommunityTab.myPosts),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CommunityTabButton({
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
          style: LocaleFontHelper.localizedTitleStyle(
            context,
            theme.textTheme.labelLarge,
          )?.copyWith(
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      Expanded(
                        child: Text(
                          component.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
