import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/community_post.dart';
import '../services/d1vai_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/card.dart';
import '../widgets/chat/markdown_text.dart';
import '../widgets/phone_frame_web_preview.dart';
import '../utils/community_post_display.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _d1vaiService = D1vaiService();

  late CommunityPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _refreshPostDetails();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = displayCommunityPostTitle(_post.title);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: RefreshIndicator(
        onRefresh: _refreshPostDetails,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildPostHeader(theme, titleText),
            const SizedBox(height: 14),
            PhoneFrameWebPreview(
              url: _post.embedUrl,
              webViewHeight: 520,
            ),
            const SizedBox(height: 14),
            _buildPostContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(ThemeData theme, String titleText) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return CustomCard(
      glass: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleText.isNotEmpty)
            Text(
              titleText,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ) ??
                  const TextStyle(fontWeight: FontWeight.w900),
            ),
          if (titleText.isNotEmpty) const SizedBox(height: 12),
          Row(
            children: [
              Hero(
                tag: communityPostAuthorHeroTag(_post),
                child: AvatarImage(
                  imageUrl: _post.author?.picture?.isNotEmpty == true
                      ? _post.author!.picture!
                      : 'placeholder',
                  size: 40,
                  borderRadius: BorderRadius.circular(20),
                  fit: BoxFit.cover,
                  placeholderText: _post.author?.picture?.isNotEmpty != true
                      ? _getAuthorDisplayName(_post.author)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getAuthorDisplayName(_post.author),
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_post.author?.email != null &&
                        _post.author!.email!.isNotEmpty)
                      Text(
                        '@${_getEmailPrefix(_post.author!.email)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ) ??
                            TextStyle(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                    colorScheme.surfaceContainerHighest,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  _formatTime(_post.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final raw = (_post.content ?? _post.summary ?? '').trim();
    final content = raw.isEmpty ? '' : raw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomCard(
          glass: true,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.isNotEmpty)
                MarkdownText(
                  text: content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.35,
                      ) ??
                      TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.35,
                      ),
                )
              else
                Text(
                  'No description yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ) ??
                      TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              if (_post.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _post.tags.map((tag) {
                    final bg = Color.alphaBlend(
                      colorScheme.primary.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      colorScheme.surface,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ) ??
                            TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if ((_post.embedUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openProjectDemo(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
