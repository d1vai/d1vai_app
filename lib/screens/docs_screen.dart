import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/snackbar_helper.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<DocItem> _pages = [
    DocItem(
      href: '/docs/overview',
      title: 'Overview',
      desc: 'What the product is and why it matters.',
      icon: Icons.info_outline,
    ),
    DocItem(
      href: '/docs/product',
      title: 'Product',
      desc: 'Value for PMs, business, and developers.',
      icon: Icons.apps,
    ),
    DocItem(
      href: '/docs/getting-started',
      title: 'Getting Started',
      desc: 'Ten steps from idea to live.',
      icon: Icons.play_circle_outline,
    ),
    DocItem(
      href: '/docs/use-cases',
      title: 'Use Cases',
      desc: 'Common indie-site scenarios.',
      icon: Icons.lightbulb_outline,
    ),
    DocItem(
      href: '/docs/architecture',
      title: 'Architecture',
      desc: 'Layers, data flow, deployment model.',
      icon: Icons.architecture,
    ),
    DocItem(
      href: '/docs/integrations',
      title: 'Integrations',
      desc: 'Auth, Payments, Analytics.',
      icon: Icons.integration_instructions,
    ),
    DocItem(
      href: '/docs/api',
      title: 'API',
      desc: 'OpenAPI viewer, auth, examples.',
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
      desc: 'Near-, mid-, and long-term plans.',
      icon: Icons.map,
    ),
    DocItem(
      href: '/docs/pricing',
      title: 'Pricing & Plans',
      desc: 'Plans and billing information.',
      icon: Icons.attach_money,
    ),
    DocItem(
      href: '/docs/refund-policy',
      title: 'Refund Policy',
      desc: 'Refund requests and dispute process.',
      icon: Icons.money_off,
    ),
    DocItem(
      href: '/docs/legal-restrictions',
      title: 'Legal Restrictions',
      desc: 'Compliance obligations and export controls.',
      icon: Icons.gavel,
    ),
  ];

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentation'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search docs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.zero,
                prefixIconColor: Colors.grey.shade600,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: _filteredPages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _filteredPages
                  .map((page) => _buildDocCard(context, page))
                  .toList(),
            ),
    );
  }

  Widget _buildDocCard(BuildContext context, DocItem page) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _navigateToDoc(context, page.href);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(page.icon, color: Colors.deepPurple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      page.desc,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDoc(BuildContext context, String href) async {
    SnackBarHelper.showInfo(
      context,
      title: 'Opening Doc',
      message: 'Opening $href...',
    );

    final url = 'https://docs.d1v.ai$href';
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
