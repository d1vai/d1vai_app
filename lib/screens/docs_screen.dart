import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';
import '../widgets/snackbar_helper.dart';

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

  final List<DocItem> _pages = [
    DocItem(
      href: '/docs/overview',
      title: 'Overview',
      desc: 'What the platform is and how the workflow fits together.',
      icon: Icons.info_outline,
    ),
    DocItem(
      href: '/docs/product',
      title: 'Product',
      desc: 'Outcomes by role (PM / Business / Developers).',
      icon: Icons.apps,
    ),
    DocItem(
      href: '/docs/getting-started',
      title: 'Getting Started',
      desc: 'Prompt → preview → production, with verification steps.',
      icon: Icons.play_circle_outline,
    ),
    DocItem(
      href: '/docs/workspace',
      title: 'Workspace Guide',
      desc:
          'Where to go in the Project workspace (Chat, Deploy, Pay, Analytics).',
      icon: Icons.workspaces_outline,
    ),
    DocItem(
      href: '/docs/use-cases',
      title: 'Use Cases',
      desc: 'Playbooks: prompts + acceptance criteria for common products.',
      icon: Icons.lightbulb_outline,
    ),
    DocItem(
      href: '/docs/architecture',
      title: 'Architecture',
      desc: 'Environments, promotion model, and failure modes.',
      icon: Icons.architecture,
    ),
    DocItem(
      href: '/docs/integrations',
      title: 'Integrations',
      desc: 'GitHub/Auth/Payments/Analytics: setup and verification.',
      icon: Icons.integration_instructions,
    ),
    DocItem(
      href: '/docs/api',
      title: 'API',
      desc: 'OpenAPI, auth, errors, pagination, webhooks.',
      icon: Icons.api,
    ),
    DocItem(
      href: '/docs/faq',
      title: 'FAQ',
      desc: 'Troubleshooting and tips.',
      icon: Icons.help_outline,
    ),
    DocItem(
      href: '/docs/roadmap',
      title: 'Roadmap',
      desc: 'Now / Next priorities (subject to change).',
      icon: Icons.map,
    ),
    DocItem(
      href: '/docs/pricing',
      title: 'Pricing & Plans',
      desc: 'Plan selection guidance and billing expectations.',
      icon: Icons.attach_money,
    ),
    DocItem(
      href: '/docs/refund-policy',
      title: 'Refund and Dispute Policy',
      desc: 'Refund/dispute process and timelines.',
      icon: Icons.money_off,
    ),
    DocItem(
      href: '/docs/privacy-policy',
      title: 'Privacy Policy',
      desc:
          'What data we collect, how we use it, and how to request export or deletion.',
      icon: Icons.privacy_tip_outlined,
    ),
    DocItem(
      href: '/docs/legal-restrictions',
      title: 'Legal and Export Restrictions',
      desc: 'Compliance and export restrictions (high-level).',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Documentation')),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHero(context),
            const SizedBox(height: 16),
            _buildSearchField(context),
            const SizedBox(height: 20),
            if (_filteredPages.isEmpty)
              _buildEmptyState(context)
            else ...[
              if (showRecent && _recentSlugs.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  eyebrow: 'History',
                  title: 'Recently viewed',
                  action: TextButton(
                    onPressed: _clearRecent,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecent(context),
                const SizedBox(height: 22),
              ],
              _buildSectionHeader(
                context,
                eyebrow: 'Library',
                title: _searchController.text.trim().isEmpty
                    ? 'Browse all documents'
                    : 'Search results',
                trailingText:
                    '${_filteredPages.length.toString().padLeft(2, '0')} items',
              ),
              const SizedBox(height: 12),
              ..._filteredPages.asMap().entries.map(
                (entry) => _buildDocCard(context, entry.value, entry.key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF131D33),
                  colorScheme.primary.withValues(alpha: 0.18),
                  const Color(0xFF1A1330),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF7F3FF),
                  const Color(0xFFFFF3F8),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : const Color(0xFF8B5CF6).withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF4F0FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFD9CCFF),
              ),
            ),
            child: Text(
              'd1v.ai docs',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Operational guidance, product context, and implementation references.',
            style: theme.textTheme.titleLarge?.copyWith(
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use the docs like a product index: scan by outcome, reopen what you touched recently, and jump straight into the detail view.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search docs, workflows, API, setup...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
          const SizedBox(height: 12),
          Text('No matching documents', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Try broader keywords or search by product area, workflow, or API topic.',
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
    required String eyebrow,
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
              Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.1,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.titleLarge),
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
      padding: const EdgeInsets.all(16),
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
        spacing: 10,
        runSpacing: 10,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDoc(context, page.href),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
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
                child: Icon(page.icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
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
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      page.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      page.desc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.north_east_rounded,
                  size: 18,
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

    // Open in-app doc viewer to reduce context switching.
    await router.push('/docs/$slug');
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
