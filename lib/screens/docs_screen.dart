import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/locale_font_helper.dart';
import '../utils/desktop_layout.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/share_sheet.dart';
import '../l10n/app_localizations.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _prefsKeyRecent = 'docs_recent_slugs';
  late final Future<SharedPreferences> _prefsFuture;
  List<String> _recentSlugs = <String>[];

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  List<DocItem> get _pages => [
    DocItem(
      href: '/docs/overview',
      title: _t('docs_page_overview_title', 'Overview'),
      desc: _t(
        'docs_page_overview_desc',
        'What the platform is and how the workflow fits together.',
      ),
      icon: Icons.info_outline,
    ),
    DocItem(
      href: '/docs/product',
      title: _t('docs_page_product_title', 'Product'),
      desc: _t(
        'docs_page_product_desc',
        'Outcomes by role (PM / Business / Developers).',
      ),
      icon: Icons.apps,
    ),
    DocItem(
      href: '/docs/getting-started',
      title: _t('docs_page_getting_started_title', 'Getting Started'),
      desc: _t(
        'docs_page_getting_started_desc',
        'Prompt -> preview -> production, with verification steps.',
      ),
      icon: Icons.play_circle_outline,
    ),
    DocItem(
      href: '/docs/workspace',
      title: _t('docs_page_workspace_title', 'Workspace Guide'),
      desc: _t(
        'docs_page_workspace_desc',
        'Where to go in the Project workspace (Chat, Deploy, Pay, Analytics).',
      ),
      icon: Icons.workspaces_outline,
    ),
    DocItem(
      href: '/docs/use-cases',
      title: _t('docs_page_use_cases_title', 'Use Cases'),
      desc: _t(
        'docs_page_use_cases_desc',
        'Playbooks: prompts + acceptance criteria for common products.',
      ),
      icon: Icons.lightbulb_outline,
    ),
    DocItem(
      href: '/docs/architecture',
      title: _t('docs_page_architecture_title', 'Architecture'),
      desc: _t(
        'docs_page_architecture_desc',
        'Environments, promotion model, and failure modes.',
      ),
      icon: Icons.architecture,
    ),
    DocItem(
      href: '/docs/integrations',
      title: _t('docs_page_integrations_title', 'Integrations'),
      desc: _t(
        'docs_page_integrations_desc',
        'GitHub/Auth/Payments/Analytics: setup and verification.',
      ),
      icon: Icons.integration_instructions,
    ),
    DocItem(
      href: '/docs/api',
      title: _t('docs_page_api_title', 'API'),
      desc: _t(
        'docs_page_api_desc',
        'OpenAPI, auth, errors, pagination, webhooks.',
      ),
      icon: Icons.api,
    ),
    DocItem(
      href: '/docs/faq',
      title: _t('docs_page_faq_title', 'FAQ'),
      desc: _t('docs_page_faq_desc', 'Troubleshooting and tips.'),
      icon: Icons.help_outline,
    ),
    DocItem(
      href: '/docs/roadmap',
      title: _t('docs_page_roadmap_title', 'Roadmap'),
      desc: _t(
        'docs_page_roadmap_desc',
        'Now / Next priorities (subject to change).',
      ),
      icon: Icons.map,
    ),
    DocItem(
      href: '/docs/refund-policy',
      title: _t('docs_page_refund_policy_title', 'Refund and Dispute Policy'),
      desc: _t(
        'docs_page_refund_policy_desc',
        'Refund/dispute process and timelines.',
      ),
      icon: Icons.money_off,
    ),
    DocItem(
      href: '/docs/privacy-policy',
      title: _t('docs_page_privacy_policy_title', 'Privacy Policy'),
      desc: _t(
        'docs_page_privacy_policy_desc',
        'What data we collect, how we use it, and how to request export or deletion.',
      ),
      icon: Icons.privacy_tip_outlined,
    ),
    DocItem(
      href: '/docs/legal-restrictions',
      title: _t(
        'docs_page_legal_restrictions_title',
        'Legal and Export Restrictions',
      ),
      desc: _t(
        'docs_page_legal_restrictions_desc',
        'Compliance and export restrictions (high-level).',
      ),
      icon: Icons.gavel,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await _prefsFuture;
    final list = prefs.getStringList(_prefsKeyRecent) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _recentSlugs = list;
    });
  }

  Future<void> _clearRecent() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_prefsKeyRecent);
    if (!mounted) return;
    setState(() {
      _recentSlugs = <String>[];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocItem> get _filteredPages {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _pages;
    return _pages
        .where((p) => ('${p.title} ${p.desc}').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRecent = _searchController.text.trim().isEmpty;
    final desktop = isDesktopLayout(context);
    final hasRecent = _recentSlugs.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('docs_title', 'Documentation'),
          style: LocaleFontHelper.localizedTitleStyle(
            context,
            theme.textTheme.titleLarge,
          ),
        ),
      ),
      body: ColoredBox(
        color: theme.colorScheme.surface,
        child: desktop
            ? DesktopContentFrame(
                maxWidth: 1440,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: hasRecent && showRecent
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSearchField(context),
                                const SizedBox(height: 18),
                                _buildSectionHeader(
                                  context,
                                  title: _t(
                                    'docs_recently_viewed',
                                    'Recently viewed',
                                  ),
                                  action: TextButton(
                                    onPressed: _clearRecent,
                                    child: Text(_t('clear', 'Clear')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _buildRecent(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VerticalDivider(
                            width: 32,
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              child: _buildDocsCatalog(context),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchField(context),
                          const SizedBox(height: 18),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildDocsCatalog(context),
                            ),
                          ),
                        ],
                      ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: [
                  _buildSearchField(context),
                  const SizedBox(height: 14),
                  _buildDocsCatalog(context),
                ],
              ),
      ),
    );
  }

  Widget _buildDocsCatalog(BuildContext context) {
    final showRecent = _searchController.text.trim().isEmpty;
    final desktop = isDesktopLayout(context);
    if (_filteredPages.isEmpty) {
      return _buildEmptyState(context);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktopLayout(context) &&
            showRecent &&
            _recentSlugs.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: _t('docs_recently_viewed', 'Recently viewed'),
            action: TextButton(
              onPressed: _clearRecent,
              child: Text(_t('clear', 'Clear')),
            ),
          ),
          const SizedBox(height: 10),
          _buildRecent(context),
          const SizedBox(height: 16),
        ],
        _buildSectionHeader(
          context,
          title: _searchController.text.trim().isEmpty
              ? _t('docs_browse_all_documents', 'Browse all documents')
              : _t('docs_search_results', 'Search results'),
          trailingText: (_t('docs_items_count', '{count} items')).replaceAll(
            '{count}',
            _filteredPages.length.toString().padLeft(2, '0'),
          ),
        ),
        const SizedBox(height: 8),
        if (desktop)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 460,
              mainAxisExtent: 126,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredPages.length,
            itemBuilder: (context, index) =>
                _buildDocCard(context, _filteredPages[index], index),
          )
        else
          ..._filteredPages.asMap().entries.map(
            (entry) => _buildDocCard(context, entry.value, entry.key),
          ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.78),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _t(
            'docs_search_hint',
            'Search docs, workflows, API, setup...',
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: _t('clear', 'Clear'),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 14,
          ),
          prefixIconColor: colorScheme.onSurfaceVariant,
          suffixIconColor: colorScheme.onSurfaceVariant,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            _t('docs_no_matching_documents', 'No matching documents'),
            style: LocaleFontHelper.localizedTitleStyle(
              context,
              theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'docs_no_matching_documents_hint',
              'Try broader keywords or search by product area, workflow, or API topic.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    String? eyebrow,
    required String title,
    Widget? action,
    String? trailingText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trailingLabel = trailingText == null
        ? null
        : Text(
            trailingText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((eyebrow ?? '').trim().isNotEmpty) ...[
                Text(
                  eyebrow!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                style: LocaleFontHelper.localizedTitleStyle(
                  context,
                  theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        ?trailingLabel,
        ?action,
      ],
    );
  }

  Widget _buildRecent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    DocItem? findBySlug(String slug) {
      for (final p in _pages) {
        final s = Uri.tryParse(p.href)?.pathSegments.last ?? '';
        if (s == slug) return p;
      }
      return null;
    }

    final items = _recentSlugs
        .map(findBySlug)
        .whereType<DocItem>()
        .toList(growable: false);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          InkWell(
            onTap: () => _navigateToDoc(context, items[index].href),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    items[index].icon,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (index != items.length - 1)
            Divider(height: 1, color: colorScheme.outlineVariant),
        ],
      ],
    );
  }

  Widget _buildDocCard(BuildContext context, DocItem page, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.78),
          ),
        ),
        child: InkWell(
          onTap: () => _navigateToDoc(context, page.href),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    page.icon,
                    color: colorScheme.onSurfaceVariant,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style:
                            LocaleFontHelper.localizedTitleStyle(
                              context,
                              theme.textTheme.titleSmall,
                            )?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        page.desc,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDoc(BuildContext context, String href) async {
    final slug = Uri.tryParse(href)?.pathSegments.isNotEmpty == true
        ? Uri.parse(href).pathSegments.last
        : href.replaceAll('/docs/', '');
    if (slug.trim().isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Open failed',
        message: 'Invalid doc link: $href',
      );
      return;
    }
    final router = GoRouter.of(context);

    // Persist recent list locally (also updated by DocDetailScreen).
    final prefs = await _prefsFuture;
    final current = slug.trim();
    final list = prefs.getStringList(_prefsKeyRecent) ?? <String>[];
    final next = <String>[current, ...list.where((s) => s != current)];
    if (next.length > 8) {
      next.removeRange(8, next.length);
    }
    await prefs.setStringList(_prefsKeyRecent, next);
    if (mounted) {
      setState(() {
        _recentSlugs = next;
      });
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      final uri = ShareLinks.docsBySlug(slug, hideHeader: true);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Open failed',
          message: 'Cannot open link: $uri',
        );
      }
      await _loadRecent();
      return;
    }

    await router.push('/docs/$slug?hideheader=true');
    await _loadRecent();
  }
}

class DocItem {
  final String href;
  final String title;
  final String desc;
  final IconData icon;

  const DocItem({
    required this.href,
    required this.title,
    required this.desc,
    required this.icon,
  });
}
