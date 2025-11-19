import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/community.dart';

/// 社区帖子卡片组件
class PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onComment;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onFavorite,
    this.onComment,
  });

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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: post.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.coverUrl,
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
                    )
                  : Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image,
                        size: 48,
                        color: Colors.grey,
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
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post.author.picture.isNotEmpty
                            ? NetworkImage(post.author.picture)
                            : null,
                        child: post.author.picture.isEmpty
                            ? Text(
                                post.author.slug.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                              post.author.slug,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPublishedDate(post.publishedAt),
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
                  Text(
                    post.summary,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // 标签
                  if (post.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: post.tags.take(3).map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 12),

                  // 底部操作栏
                  Row(
                    children: [
                      // 点赞
                      InkWell(
                        onTap: onFavorite,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Like',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 评论
                      InkWell(
                        onTap: onComment,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Comment',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 查看链接
                      if ((post.embedUrl ?? '').isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _openProjectDemo(context);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
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

  /// 格式化发布日期
  String _formatPublishedDate(DateTime dateTime) {
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
                title: const Text('Share'),
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
  void _sharePost(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  /// 保存帖子
  void _savePost(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save functionality coming soon')),
    );
  }

  /// 举报帖子
  void _reportPost(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report functionality coming soon')),
    );
  }

  /// 打开项目演示链接
  void _openProjectDemo(BuildContext context) {
    if ((post.embedUrl ?? '').isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opening ${post.title}...')));
      // TODO: 使用 url_launcher 打开链接
    }
  }
}
