import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/community_skill.dart';
import '../services/d1vai_service.dart';
import 'card.dart';

class CommunitySkillsTab extends StatefulWidget {
  final String searchQuery;

  const CommunitySkillsTab({super.key, required this.searchQuery});

  @override
  State<CommunitySkillsTab> createState() => _CommunitySkillsTabState();
}

class _CommunitySkillsTabState extends State<CommunitySkillsTab> {
  static const _pageSize = 20;
  final _service = D1vaiService();
  final List<CommunitySkill> _skills = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommunitySkillsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) _load(refresh: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter < 320) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loadingMore || (!refresh && !_hasMore)) return;
    setState(() {
      if (refresh) {
        _loading = true;
        _offset = 0;
        _hasMore = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await _service.getCommunitySkills(
        limit: _pageSize,
        offset: refresh ? 0 : _offset,
        searchQuery: widget.searchQuery,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _skills.clear();
        _skills.addAll(page);
        _offset = _skills.length;
        _hasMore = page.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _skills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _skills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 34),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _load(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('retry', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_skills.isEmpty) {
      return Center(
        child: Text(
          widget.searchQuery.trim().isEmpty
              ? _t('community_no_skills_yet', 'No skills yet')
              : _t('community_no_results', 'No results found'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 2 : 1,
              mainAxisExtent: 190,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _skills.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _skills.length) {
                return Center(
                  child: _loadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(_t('load_more', 'Load more')),
                        ),
                );
              }
              return _CommunitySkillCard(skill: _skills[index], t: _t);
            },
          );
        },
      ),
    );
  }
}

class _CommunitySkillCard extends StatelessWidget {
  final CommunitySkill skill;
  final String Function(String, String) t;

  const _CommunitySkillCard({required this.skill, required this.t});

  Future<void> _openSource() async {
    final url = Uri.tryParse(skill.repoUrl);
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tags = skill.sourceTags.take(3).toList(growable: false);
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (skill.version?.trim().isNotEmpty == true)
                Text(
                  skill.version!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            skill.description.isEmpty
                ? t(
                    'community_skill_no_description',
                    'No description provided.',
                  )
                : skill.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (skill.category.trim().isNotEmpty)
                _Tag(label: skill.category, color: cs.secondary),
              ...tags.map(
                (tag) => _Tag(label: tag, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.publisherName?.trim().isNotEmpty == true
                      ? skill.publisherName!
                      : skill.slug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('github', 'GitHub'),
                onPressed: skill.repoUrl.trim().isEmpty ? null : _openSource,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
