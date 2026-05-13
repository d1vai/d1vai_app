import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
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
    final isDark = theme.brightness == Brightness.dark;
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
              isDark ? const Color(0xFF111827) : const Color(0xFFFDF7FB),
            ],
          ),
        ),
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
                          const SizedBox(width: 24),
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
              maxCrossAxisExtent: 420,
              mainAxisExtent: 170,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.86),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.12)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((eyebrow ?? '').trim().isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.1,
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
                  theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildRecent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.82),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((p) {
          return ActionChip(
            avatar: Icon(p.icon, size: 16, color: colorScheme.primary),
            label: Text(p.title),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
            backgroundColor: isDark
                ? colorScheme.primary.withValues(alpha: 0.12)
                : const Color(0xFFF5F3FF),
            side: BorderSide(
              color: isDark
                  ? colorScheme.primary.withValues(alpha: 0.26)
                  : const Color(0xFFD9CCFF),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onPressed: () => _navigateToDoc(context, p.href),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, DocItem page, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentForIndex(index);
    final tag = _tagForItem(page);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.04),
                  accent.withValues(alpha: 0.10),
                ]
              : [Colors.white, accent.withValues(alpha: 0.07)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.10)
                : const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDoc(context, page.href),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.34 : 0.18),
                      accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.32 : 0.18),
                  ),
                ),
                child: Icon(page.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                page.title,
                                style:
                                    LocaleFontHelper.localizedTitleStyle(
                                      context,
                                      theme.textTheme.titleMedium,
                                    )?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      page.desc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.28,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForIndex(int index) {
    const accents = <Color>[
      AppColors.primaryBrand,
      AppColors.secondaryBrand,
      AppColors.info,
      AppColors.success,
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
    ];
    return accents[index % accents.length];
  }

  String _tagForItem(DocItem page) {
    final title = page.title.toLowerCase();
    if (title.contains('api')) return 'Reference';
    if (title.contains('faq')) return 'Support';
    if (title.contains('pricing') || title.contains('refund')) return 'Policy';
    if (title.contains('legal')) return 'Compliance';
    if (title.contains('roadmap')) return 'Planning';
    if (title.contains('architecture') || title.contains('integrations')) {
      return 'Technical';
    }
    if (title.contains('overview') || title.contains('product')) return 'Core';
    return 'Guide';
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
