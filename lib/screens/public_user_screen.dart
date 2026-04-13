import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/prompt_activity.dart';
import '../models/user.dart';
import '../services/d1vai_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/prompt_activity_heatmap.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';

class PublicUserScreen extends StatefulWidget {
  final String slug;

  const PublicUserScreen({super.key, required this.slug});

  @override
  State<PublicUserScreen> createState() => _PublicUserScreenState();
}

class _PublicUserScreenState extends State<PublicUserScreen> {
  final D1vaiService _service = D1vaiService();

  bool _loading = true;
  String? _error;
  User? _user;
  PromptDailyActivity? _activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _trimmedSlug => widget.slug.trim();

  Future<void> _load() async {
    final slug = _trimmedSlug;
    if (slug.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing user slug';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rawUser = await _service.getPublicUserBySlug(slug);
      PromptDailyActivity? activity;
      try {
        activity = await _service.getPublicPromptDailyActivityBySlug(
          slug,
          days: 182,
        );
      } catch (_) {
        activity = null;
      }
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(rawUser);
        _activity = activity;
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

  String _displayName(User user) {
    final slug = (user.slug ?? '').trim();
    if (slug.isNotEmpty) return slug;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) {
      final at = email.indexOf('@');
      return at > 0 ? email.substring(0, at) : email;
    }
    return user.sub.trim().isNotEmpty ? user.sub.trim() : 'User #${user.id}';
  }

  Future<void> _openWebsite(String website) async {
    final raw = website.trim();
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (parsed == null) return;
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    SnackBarHelper.showError(
      context,
      title: 'Open failed',
      message: 'Cannot open website',
    );
  }

  Future<void> _openInBrowser() async {
    final uri = ShareLinks.publicUserBySlug(_trimmedSlug);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    SnackBarHelper.showError(
      context,
      title: 'Open failed',
      message: 'Cannot open profile',
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(displayValue),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? 'Profile' : _displayName(user)),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: _trimmedSlug.isEmpty
                ? null
                : () {
                    ShareSheet.show(
                      context,
                      url: ShareLinks.publicUserBySlug(_trimmedSlug),
                      title: user == null
                          ? 'Public profile'
                          : _displayName(user),
                      message: 'Open this public creator profile on d1v.ai.',
                    );
                  },
          ),
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: _trimmedSlug.isEmpty ? null : _openInBrowser,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(_error ?? 'Profile not found'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          AvatarImage(
                            imageUrl: user.picture.isEmpty
                                ? 'placeholder'
                                : user.picture,
                            size: 84,
                            borderRadius: BorderRadius.circular(42),
                            placeholderText: _displayName(user),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _displayName(user),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.companyName.trim().isNotEmpty
                                ? user.companyName.trim()
                                : user.industry.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_activity != null)
                    PromptActivityHeatmap(activity: _activity!, weeks: 26)
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Prompt activity is not available.'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.business_center_outlined,
                    label: 'Industry',
                    value: user.industry,
                  ),
                  _buildInfoTile(
                    icon: Icons.apartment_outlined,
                    label: 'Company',
                    value: user.companyName,
                  ),
                  _buildInfoTile(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: user.companyWebsite,
                    onTap: user.companyWebsite.trim().isEmpty
                        ? null
                        : () => _openWebsite(user.companyWebsite),
                  ),
                ],
              ),
            ),
    );
  }
}
