import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../services/d1vai_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/chat/markdown_text.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/phone_frame_web_preview.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';
import '../utils/community_post_display.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _d1vaiService = D1vaiService();
  final ScrollController _scrollController = ScrollController();

  late CommunityPost _post;
  final List<_LocalComment> _localComments = <_LocalComment>[];
  bool _showFrost = false;
  bool _isSnapping = false;
  ScrollDirection _lastUserScrollDirection = ScrollDirection.idle;

  static const double _tagStripHeight = 40.0;
  static const double _tagStripGap = 10.0;
  static const double _cardInnerPadding = 14.0;

  double _collapsedHeight = 140.0;
  double _expandedHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _refreshPostDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showFrost = true;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeSnapAppBar() async {
    if (_isSnapping) return;
    if (!_scrollController.hasClients) return;

    final collapseRange = (_expandedHeight - _collapsedHeight).clamp(
      0.0,
      double.infinity,
    );

    if (collapseRange <= 0) return;

    final offset = _scrollController.offset;
    if (offset <= 0 || offset >= collapseRange) return;

    final target =
        switch (_lastUserScrollDirection) {
          ScrollDirection.forward => 0.0,
          ScrollDirection.reverse => collapseRange,
          _ => offset < (collapseRange * 0.5) ? 0.0 : collapseRange,
        };

    if ((offset - target).abs() < 1.0) return;

    _isSnapping = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isSnapping = false;
    }
  }

  Future<void> _refreshPostDetails() async {
    try {
      final updatedPost = await _d1vaiService.getCommunityPostDetails(_post.id);
      if (mounted) {
        setState(() {
          _post = updatedPost;
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh post details: $e');
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
        return DateFormat('MMM d, yyyy').format(dateTime);
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

  String _getAuthorDisplayName(Author? author) {
    final slug = author?.slug;
    if (slug != null && slug.isNotEmpty) {
      return slug;
    }
    final email = author?.email;
    if (email != null && email.isNotEmpty) {
      final prefix = _getEmailPrefix(email);
      return prefix.isNotEmpty ? prefix : 'Anonymous';
    }
    return 'Anonymous';
  }

  double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
  }) {
    if (text.trim().isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  double _estimateCardHeight(
    ThemeData theme, {
    required String titleText,
    required String summaryText,
    required String contentText,
    required bool expanded,
  }) {
    final safeTitle = titleText.isEmpty ? 'Post' : titleText;
    final previewText = (contentText.isNotEmpty ? contentText : summaryText);
    final titleStyle =
        theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: expanded ? 20 : 16,
          height: 1.05,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: expanded ? 20 : 16,
          height: 1.05,
        );
    final summaryStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 13,
          height: 1.25,
        ) ??
        TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 13,
          height: 1.25,
        );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHorizontal = 16.0;
    final outerWidth = (screenWidth - (cardHorizontal * 2)).clamp(
      240.0,
      double.infinity,
    );
    final innerWidth = (outerWidth - (_cardInnerPadding * 2)).clamp(
      200.0,
      double.infinity,
    );
    final titleMaxWidth = (innerWidth - 96.0).clamp(160.0, double.infinity);

    final titleHeight = _measureTextHeight(
      text: safeTitle,
      style: titleStyle,
      maxWidth: titleMaxWidth,
      maxLines: expanded ? 2 : 1,
    );
    final authorRowHeight = expanded ? 34.0 : 28.0;
    final summaryHeight =
        previewText.trim().isEmpty
            ? 0.0
            : _measureTextHeight(
              text: previewText,
              style: summaryStyle,
              maxWidth: innerWidth,
              maxLines: expanded ? 6 : 2,
            );

    return (_cardInnerPadding +
            titleHeight +
            10 +
            authorRowHeight +
            (summaryHeight > 0 ? (10 + summaryHeight) : 0) +
            _cardInnerPadding +
            8)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = displayCommunityPostTitle(_post.title);
    final summaryText =
        (_post.summary ?? _post.content ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final contentText = (_post.content ?? _post.summary ?? '').trim();
    final topPadding = MediaQuery.paddingOf(context).top;
    final hasTags = _post.tags.isNotEmpty;

    final collapsedCardHeight = _estimateCardHeight(
      theme,
      titleText: titleText,
      summaryText: summaryText,
      contentText: contentText,
      expanded: false,
    );
    final expandedCardHeight = _estimateCardHeight(
      theme,
      titleText: titleText,
      summaryText: summaryText,
      contentText: contentText,
      expanded: true,
    );

    final cardTopCollapsed = topPadding + 2;
    final cardTopExpanded = topPadding + 10;
    final collapsedHeight = (cardTopCollapsed + collapsedCardHeight + 10)
        .toDouble();
    final expandedHeight =
        (cardTopExpanded +
                expandedCardHeight +
                (hasTags ? (_tagStripGap + _tagStripHeight + 8) : 0) +
                12)
            .toDouble();

    _collapsedHeight = collapsedHeight;
    _expandedHeight = expandedHeight;

    final previewTotalHeightRaw =
        MediaQuery.sizeOf(context).height - collapsedHeight;
    final previewTotalHeight =
        (previewTotalHeightRaw < 280.0 ? 280.0 : previewTotalHeightRaw)
            .toDouble();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshPostDetails,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is UserScrollNotification) {
              _lastUserScrollDirection = n.direction;
            } else if (n is ScrollEndNotification) {
              _maybeSnapAppBar();
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildFrostedAppBar(
                theme,
                titleText: titleText,
                summaryText: summaryText,
                contentText: contentText,
                collapsedHeight: collapsedHeight,
                expandedHeight: expandedHeight,
                collapsedCardHeight: collapsedCardHeight,
                expandedCardHeight: expandedCardHeight,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: PhoneFrameWebPreview(
                    url: _post.embedUrl,
                    height: previewTotalHeight,
                    padding: const EdgeInsets.all(14),
                    allowParentVerticalScroll: true,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: _buildCommentsSection(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _ensureLoggedIn() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) return true;
    showDialog(
      context: context,
      builder: (_) => const LoginRequiredDialog(),
    );
    return false;
  }

  Future<void> _openCommentComposer() async {
    if (!_ensureLoggedIn()) return;

    final controller = TextEditingController();
    String? posted;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write a comment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Be kind. Add details that help others…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    posted = text;
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Post (local)'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      controller.dispose();
      return;
    }

    final text = (posted ?? '').trim();
    controller.dispose();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    setState(() {
      _localComments.insert(
        0,
        _LocalComment(
          authorName: user.slug ?? user.email ?? 'You',
          authorAvatarUrl: user.picture,
          content: text,
          createdAt: DateTime.now(),
        ),
      );
    });

    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Posted',
      message: 'Comment added locally (API coming soon)',
    );
  }

  Widget _buildCommentsSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final totalCount = _post.commentCount + _localComments.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Comments ($totalCount)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _openCommentComposer,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Comment'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_localComments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  'No comments yet. Start the discussion.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: _localComments
                    .take(12)
                    .map((c) => _CommentTile(comment: c))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsStrip(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final tags = _post.tags.take(12).toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _showFrost ? 14 : 0,
          sigmaY: _showFrost ? 14 : 0,
        ),
        child: Container(
          height: _tagStripHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.20),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.10 : 0.16,
                    ),
                  ),
                ),
                child: Text(
                  tag,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        fontSize: 12,
                      ) ??
                      const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        fontSize: 12,
                      ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildFrostedAppBar(
    ThemeData theme, {
    required String titleText,
    required String summaryText,
    required String contentText,
    required double collapsedHeight,
    required double expandedHeight,
    required double collapsedCardHeight,
    required double expandedCardHeight,
  }) {
    final coverUrl = _post.coverUrl?.trim() ?? '';
    final hasCover = coverUrl.isNotEmpty;
    final topPadding = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      stretch: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      collapsedHeight: collapsedHeight,
      expandedHeight: expandedHeight,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings =
              context.dependOnInheritedWidgetOfExactType<
                FlexibleSpaceBarSettings
              >();
          final currentExtent = settings?.currentExtent ?? constraints.maxHeight;
          final minExtent = settings?.minExtent ?? collapsedHeight;
          final maxExtent = settings?.maxExtent ?? expandedHeight;
          final t =
              ((currentExtent - minExtent) / (maxExtent - minExtent)).clamp(
                0.0,
                1.0,
              );

          final cardTop = ui.lerpDouble(topPadding + 2, topPadding + 10, t)!;
          final cardHeight =
              ui.lerpDouble(collapsedCardHeight, expandedCardHeight, t)!;
          final cardHorizontal = ui.lerpDouble(12, 16, t)!;
          final titleFont = ui.lerpDouble(16, 20, t)!;
          final titleLines = t < 0.35 ? 1 : 2;
          final avatarSize = ui.lerpDouble(28, 34, t)!;
          final overlayOpacity = ui.lerpDouble(0.18, 0.34, t)!;
          final isDark = theme.brightness == Brightness.dark;
          final glassBg =
              isDark
                  ? Colors.black.withValues(alpha: ui.lerpDouble(0.12, 0.18, t)!)
                  : Colors.white.withValues(
                    alpha: ui.lerpDouble(0.08, 0.12, t)!,
                  );
          final glassBorder =
              isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.20);

          Widget background = DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.24),
                  theme.colorScheme.surfaceContainerHighest,
                ],
              ),
            ),
          );

          if (hasCover) {
            background = Hero(
              tag: communityPostCoverHeroTag(_post),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                alignment: Alignment(0, ui.lerpDouble(-0.10, 0.15, t)!),
                fadeInDuration: const Duration(milliseconds: 120),
                fadeOutDuration: const Duration(milliseconds: 120),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: background),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: overlayOpacity),
                        Colors.black.withValues(alpha: overlayOpacity + 0.10),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cardHorizontal,
                right: cardHorizontal,
                top: cardTop,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _showFrost ? 16 : 0,
                      sigmaY: _showFrost ? 16 : 0,
                    ),
                    child: Container(
                      height: cardHeight,
                      padding: const EdgeInsets.all(_cardInnerPadding),
                      decoration: BoxDecoration(
                        color: glassBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: glassBorder),
                      ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _buildAppBarCardContent(
                          theme,
                          t: t,
                          titleText: titleText,
                          titleFontSize: titleFont,
                          titleMaxLines: titleLines,
                          summaryText: summaryText,
                          contentText: contentText,
                          avatarSize: avatarSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_post.tags.isNotEmpty)
                Positioned(
                  left: cardHorizontal,
                  right: cardHorizontal,
                  top: cardTop + cardHeight + (_tagStripGap * t),
                  child: IgnorePointer(
                    ignoring: t < 0.35,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: t,
                      child: Opacity(
                        opacity: Curves.easeOutCubic.transform(
                          ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                        ),
                        child: _buildTagsStrip(theme),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBarCardContent(
    ThemeData theme, {
    required double t,
    required String titleText,
    required double titleFontSize,
    required int titleMaxLines,
    required String summaryText,
    required String contentText,
    required double avatarSize,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final authorPrefix = _getEmailPrefix(_post.author?.email ?? '');

    final showCta = (_post.embedUrl ?? '').trim().isNotEmpty;

    final previewText = contentText.isNotEmpty ? contentText : summaryText;
    final summaryLines = t < 0.25 ? 2 : (t < 0.60 ? 3 : 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GlassIconButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titleText.isEmpty ? 'Post' : titleText,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: titleFontSize,
                      height: 1.05,
                    ) ??
                    TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: titleFontSize,
                      height: 1.05,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            _GlassIconButton(
              icon: Icons.share,
              onPressed: () {
                final url = ShareLinks.communityPostBySlug(_post.slug);
                ShareSheet.show(
                  context,
                  url: url,
                  title: titleText.isEmpty ? 'Post' : titleText,
                  message: summaryText.trim().isEmpty ? null : summaryText.trim(),
                );
              },
            ),
            const SizedBox(width: 10),
            if (showCta)
              _GlassIconButton(
                icon: Icons.open_in_new,
                onPressed: () => _openProjectDemo(context),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Hero(
              tag: communityPostAuthorHeroTag(_post),
              child: RepaintBoundary(
                child: AvatarImage(
                  imageUrl:
                      _post.author?.picture?.isNotEmpty == true
                          ? _post.author!.picture!
                          : 'placeholder',
                  size: avatarSize,
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                  fit: BoxFit.cover,
                  showBorder: false,
                  placeholderText:
                      _post.author?.picture?.isNotEmpty != true
                          ? _getAuthorDisplayName(_post.author)
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getAuthorDisplayName(_post.author),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ) ??
                        const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(_post.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                        ) ??
                        TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            if (authorPrefix.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.16),
                  ),
                ),
                child: Text(
                  '@$authorPrefix',
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w800,
                      ) ??
                      TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
          ],
        ),
        if (previewText.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          MarkdownText(
            text: previewText,
            maxLines: summaryLines,
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 13,
                  height: 1.25,
                ) ??
                TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 13,
                  height: 1.25,
                ),
          ),
        ],
      ],
    );
  }

  /// 打开项目演示链接
  void _openProjectDemo(BuildContext context) async {
    final url = (_post.embedUrl ?? '').trim();
    if (url.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${displayCommunityPostTitle(_post.title)}...'),
          duration: const Duration(seconds: 1),
        ),
      );
      try {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        final ok = await canLaunchUrl(uri);
        if (!ok) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open link: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.18),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _LocalComment {
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const _LocalComment({
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });
}

class _CommentTile extends StatelessWidget {
  final _LocalComment comment;

  const _CommentTile({required this.comment});

  String _timeAgo() {
    final diff = DateTime.now().difference(comment.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarImage(
            imageUrl:
                (comment.authorAvatarUrl ?? '').trim().isNotEmpty
                    ? comment.authorAvatarUrl!.trim()
                    : 'placeholder',
            size: 34,
            borderRadius: BorderRadius.circular(12),
            fit: BoxFit.cover,
            showBorder: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.authorName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _timeAgo(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
