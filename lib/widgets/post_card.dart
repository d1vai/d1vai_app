import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/services.dart';
import '../models/community_post.dart';
import 'avatar_image.dart';
import 'snackbar_helper.dart';
import 'card.dart';

/// 社区帖子卡片组件
class PostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final scale = Tween<double>(begin: 1, end: 0.992).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    final coverUrl = post.coverUrl?.trim() ?? '';
    final hasCover = coverUrl.isNotEmpty;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCover)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: coverUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
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
                          height: 180,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
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
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.22),
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
                              final a = isDark ? (0.14 * (1 - t)) : (0.10 * (1 - t));
                              return Opacity(
                                opacity: a.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset((t - 0.5) * 260, 0),
                                  child: Transform.rotate(
                                    angle: -0.35,
                                    child: Container(
                                      width: 160,
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
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvatarImage(
                          imageUrl: post.author?.picture?.isNotEmpty == true
                              ? post.author!.picture!
                              : 'placeholder',
                          size: 40,
                          borderRadius: BorderRadius.circular(20),
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                post.author?.slug ?? 'Anonymous',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ) ??
                                    const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatPublishedDate(post.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ) ??
                                    TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => _showMoreOptions(context),
                          tooltip: 'More',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w900),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post.summary != null && post.summary!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.summary!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                              height: 1.25,
                            ) ??
                            TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                              height: 1.25,
                            ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
                title: const Text('Share (copy link)'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePost(context);
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

  /// 分享帖子
  void _sharePost(BuildContext context) async {
    final link = 'https://www.d1v.ai/c/${widget.post.slug}';
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Share link copied',
      );
    }
  }

  /// 保存帖子
  void _savePost(BuildContext context) {
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'Save functionality coming soon',
    );
  }

  /// 举报帖子
  void _reportPost(BuildContext context) {
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'Report functionality coming soon',
    );
  }
}
