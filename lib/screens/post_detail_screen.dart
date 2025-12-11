import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/community_post.dart';
import '../services/d1vai_service.dart';
import '../widgets/avatar_image.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Post Details')),
      body: RefreshIndicator(
        onRefresh: _refreshPostDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPostHeader(theme),
            const SizedBox(height: 16),
            _buildPostContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(ThemeData theme) {
    return Row(
      children: [
        AvatarImage(
          imageUrl: _post.author?.picture?.isNotEmpty == true
              ? _post.author!.picture!
              : 'placeholder',
          size: 48,
          borderRadius: BorderRadius.circular(24),
          fit: BoxFit.cover,
          placeholderText: _post.author?.picture?.isNotEmpty != true
              ? _getAuthorDisplayName(_post.author)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getAuthorDisplayName(_post.author),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_post.author?.email != null &&
                  _post.author!.email!.isNotEmpty)
                Text(
                  '@${_getEmailPrefix(_post.author!.email)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Text(
          _formatTime(_post.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_post.title.isNotEmpty)
          Text(
            _post.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 12),
        if (_post.coverUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _post.coverUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _post.content ?? _post.summary ?? '',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),

        // Tags
        if (_post.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _post.tags.map((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // View Project Button
        if ((_post.embedUrl ?? '').isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _openProjectDemo(context);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('View Project'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  /// 打开项目演示链接
  void _openProjectDemo(BuildContext context) async {
    if ((_post.embedUrl ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${_post.title}...'),
          duration: const Duration(seconds: 1),
        ),
      );
      final url = _post.embedUrl!;
      try {
        // ignore: deprecated_member_use
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
