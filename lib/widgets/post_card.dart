import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/services.dart';
import '../models/community_post.dart';
import 'avatar_image.dart';
import 'snackbar_helper.dart';

/// 社区帖子卡片组件
class PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            if (post.coverUrl != null && post.coverUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: post.coverUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),

            // 帖子内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 作者信息
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPublishedDate(post.createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () {
                          _showMoreOptions(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 标题
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // 摘要
                  if (post.summary != null && post.summary!.isNotEmpty)
                    Text(
                      post.summary!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final link = 'https://www.d1v.ai/c/${post.slug}';
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
