import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/d1vai_service.dart';
import 'post_detail_screen.dart';

class CommunityPostLinkScreen extends StatefulWidget {
  final String slug;

  const CommunityPostLinkScreen({super.key, required this.slug});

  @override
  State<CommunityPostLinkScreen> createState() =>
      _CommunityPostLinkScreenState();
}

class _CommunityPostLinkScreenState extends State<CommunityPostLinkScreen> {
  final _service = D1vaiService();
  bool _loading = true;
  String? _error;
  CommunityPost? _post;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final slug = widget.slug.trim();
      if (slug.isEmpty) {
        throw Exception('Missing slug');
      }

      final post = await _service.getCommunityPostDetails(slug);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final post = _post;
    if (post != null) {
      return PostDetailScreen(post: post);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Failed to load post'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
