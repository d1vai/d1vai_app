import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../utils/community_post_display.dart';
import 'avatar_image.dart';
import 'login_required_dialog.dart';
import 'snackbar_helper.dart';
import 'card.dart';
import 'share_sheet.dart';

/// 社区帖子卡片组件
class PostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shineController;

  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;

  String _displayTitle(String raw) {
    return raw.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.updatedAt != widget.post.updatedAt) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _commentCount = widget.post.commentCount;
    }
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

  void _toggleLike() {
    if (!_ensureLoggedIn()) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = (_likeCount + (_isLiked ? 1 : -1)).clamp(0, 1 << 30);
    });
    SnackBarHelper.showSuccess(
      context,
      title: _isLiked ? 'Liked' : 'Unliked',
      message: widget.post.title,
    );
  }

  void _openComments() {
    if (!_ensureLoggedIn()) return;
    HapticFeedback.selectionClick();
    widget.onTap?.call();
    SnackBarHelper.showInfo(
      context,
      title: 'Comments',
      message: 'Comments UI coming soon',
    );
  }

  void _sharePostSheet() {
    final url = ShareLinks.communityPostBySlug(widget.post.slug);
    ShareSheet.show(
      context,
      url: url,
      title: widget.post.title,
      message: (widget.post.summary ?? '').trim().isNotEmpty
          ? widget.post.summary!.trim()
          : '/c/${widget.post.slug}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final scale = Tween<double>(
      begin: 1,
      end: 0.992,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    final coverUrl = post.coverUrl?.trim() ?? '';
    final hasCover = coverUrl.isNotEmpty;
    final height = hasCover ? 220.0 : 170.0;
    final glassBg = Colors.black.withValues(alpha: isDark ? 0.35 : 0.26);
    final glassBorder = Colors.white.withValues(alpha: isDark ? 0.14 : 0.18);
    final titleText = _displayTitle(post.title);
    final summaryText = (post.summary ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final card = CustomCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap?.call();
          },
          onTapDown: (_) {
            _pressController.forward();
            if (!_shineController.isAnimating) {
              _shineController.forward(from: 0);
            }
          },
          onTapCancel: () => _pressController.reverse(),
          onTapUp: (_) => _pressController.reverse(),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: hasCover
                        ? Hero(
                            tag: communityPostCoverHeroTag(post),
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.primary.withValues(alpha: 0.25),
                                  colorScheme.surfaceContainerHighest,
                                ],
                              ),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.62),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shineController,
                        builder: (context, _) {
                          final t = Curves.easeOutCubic.transform(
                            _shineController.value,
                          );
                          final a = isDark
                              ? (0.16 * (1 - t))
                              : (0.12 * (1 - t));
                          return Opacity(
                            opacity: a.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset((t - 0.5) * 340, 0),
                              child: Transform.rotate(
                                angle: -0.35,
                                child: Container(
                                  width: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          decoration: BoxDecoration(
                            color: glassBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      titleText,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            height: 1.08,
                                            color: Colors.white,
                                          ) ??
                                          const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: isDark ? 0.10 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: isDark ? 0.12 : 0.16,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Hero(
                                          tag: communityPostAuthorHeroTag(post),
                                          child: AvatarImage(
                                            imageUrl:
                                                post
                                                        .author
                                                        ?.picture
                                                        ?.isNotEmpty ==
                                                    true
                                                ? post.author!.picture!
                                                : 'placeholder',
                                            size: 20,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            fit: BoxFit.cover,
                                            showBorder: false,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            post.author?.slug ?? 'Anonymous',
                                            style:
                                                theme.textTheme.labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      height: 1.0,
                                                    ) ??
                                                const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.more_horiz,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    onPressed: () => _showMoreOptions(context),
                                    tooltip: 'More',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (summaryText.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        summaryText,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.86,
                                              ),
                                              height: 1.2,
                                            ) ??
                                            TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.86,
                                              ),
                                              height: 1.2,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatPublishedDate(post.createdAt),
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.76,
                                          ),
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ) ??
                                        TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.76,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _ActionPill(
                                    icon: _isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    label: _likeCount.toString(),
                                    onTap: _toggleLike,
                                    active: _isLiked,
                                  ),
                                  const SizedBox(width: 10),
                                  _ActionPill(
                                    icon: Icons.chat_bubble_outline,
                                    label: _commentCount.toString(),
                                    onTap: _openComments,
                                  ),
                                  const Spacer(),
                                  _ActionPill(
                                    icon: Icons.share,
                                    label: 'Share',
                                    onTap: _sharePostSheet,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return ScaleTransition(scale: scale, child: card);
  }

  /// 格式化发布日期
  String _formatPublishedDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// 显示更多选项菜单
  void _showMoreOptions(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePostSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('Save'),
                onTap: () {
                  Navigator.pop(context);
                  _savePost(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 保存帖子
  void _savePost(BuildContext context) {
    if (!_ensureLoggedIn()) return;
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'Save functionality coming soon',
    );
  }

  /// 举报帖子
  void _reportPost(BuildContext context) {
    if (!_ensureLoggedIn()) return;
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'Report functionality coming soon',
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = Colors.white.withValues(alpha: active ? 1.0 : 0.9);
    final bg = Colors.white.withValues(alpha: active ? 0.16 : 0.10);
    final border = Colors.white.withValues(alpha: active ? 0.20 : 0.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ) ??
                    TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
