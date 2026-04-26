import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../widgets/snackbar_helper.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<String> _faqIds = [
    'create_project',
    'connect_github',
    'payment_methods',
    'invite_friends',
    'change_email',
    'reset_password',
    'light_dark_mode',
    'delete_account',
  ];

  // 联系支持邮箱
  static const String supportEmail = 'support@d1v.ai';

  // 文档链接
  static const String docsUrl = 'https://www.d1v.ai/docs/overview';

  // 用户指南链接
  static const String userGuideUrl = 'https://www.d1v.ai/docs/getting-started';

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  List<Map<String, String>> _faqs(BuildContext context) {
    final fallback = <String, Map<String, String>>{
      'create_project': {
        'question': 'How do I create a new project?',
        'answer':
            'Navigate to the Projects tab and tap the "+" button. You can either create a new project from scratch or import from GitHub.',
      },
      'connect_github': {
        'question': 'How do I connect my GitHub account?',
        'answer':
            'Go to Settings > GitHub tab. Enter your Personal Access Token with the required permissions (repo, read:user, user:email, read:org, workflow).',
      },
      'payment_methods': {
        'question': 'What payment methods are supported?',
        'answer':
            'We currently support credit/debit cards through Stripe. More payment methods will be added in future updates.',
      },
      'invite_friends': {
        'question': 'How do I invite friends?',
        'answer':
            'Go to Settings > Invites tab. You can share your unique invite code or invitation link. You can invite up to 3 users within a 7-day window.',
      },
      'change_email': {
        'question': 'Can I change my email address?',
        'answer':
            'Yes! Go to Settings > Profile tab and tap on the email field. You\'ll need to verify your new email address.',
      },
      'reset_password': {
        'question': 'How do I reset my password?',
        'answer':
            'In Settings > Profile tab, tap on "Reset Password". You\'ll receive a verification code via email to complete the process.',
      },
      'light_dark_mode': {
        'question': 'What is the difference between Light and Dark mode?',
        'answer':
            'Light mode uses a bright theme ideal for daytime use. Dark mode uses a darker theme that\'s easier on the eyes in low-light conditions. You can also set it to follow your system settings.',
      },
      'delete_account': {
        'question': 'How do I delete my account?',
        'answer':
            'Please contact our support team at support@d1v.ai to request account deletion. We\'ll process your request within 48 hours.',
      },
    };

    return _faqIds.map((id) {
      final item = fallback[id]!;
      return {
        'question': _t(
          context,
          'help_support_faq_${id}_question',
          item['question']!,
        ),
        'answer': _t(context, 'help_support_faq_${id}_answer', item['answer']!),
      };
    }).toList();
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=Help & Support Request',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          SnackBarHelper.showError(
            context,
            title: _t(context, 'error', 'Error'),
            message: _t(
              context,
              'help_support_email_open_failed',
              'Could not open email app. Please email us at {email}',
            ).replaceAll('{email}', supportEmail),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          title: _t(context, 'error', 'Error'),
          message: _t(
            context,
            'help_support_email_open_error',
            'Failed to open email: {error}',
          ).replaceAll('{error}', e.toString()),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url, String name) async {
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          SnackBarHelper.showError(
            context,
            title: _t(context, 'error', 'Error'),
            message: _t(
              context,
              'help_support_link_open_failed',
              'Could not open {name}',
            ).replaceAll('{name}', name),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          title: _t(context, 'error', 'Error'),
          message: _t(
            context,
            'help_support_link_open_error',
            'Failed to open {name}: {error}',
          ).replaceAll('{name}', name).replaceAll('{error}', e.toString()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final faqs = _faqs(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'help_support', 'Help & Support')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
              isDark ? const Color(0xFF0F172A) : const Color(0xFFFDF7FB),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeroCard(context),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              _t(context, 'help_support_quick_actions', 'Quick Actions'),
              eyebrow: 'Support',
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              context,
              icon: Icons.email_outlined,
              title: _t(context, 'contact_support', 'Contact Support'),
              subtitle: _t(
                context,
                'help_support_contact_subtitle',
                'Email us at {email}',
              ).replaceAll('{email}', supportEmail),
              onTap: () => _launchEmail(context),
              accent: colorScheme.primary,
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context,
              icon: Icons.menu_book_outlined,
              title: _t(context, 'help_support_user_guide_title', 'User Guide'),
              subtitle: _t(
                context,
                'help_support_user_guide_subtitle',
                'Learn how to use all features',
              ),
              onTap: () => _launchUrl(
                context,
                userGuideUrl,
                _t(context, 'help_support_user_guide_title', 'User Guide'),
              ),
              accent: const Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context,
              icon: Icons.description_outlined,
              title: _t(context, 'docs', 'Documentation'),
              subtitle: _t(
                context,
                'help_support_docs_subtitle',
                'Technical documentation and API reference',
              ),
              onTap: () => _launchUrl(
                context,
                docsUrl,
                _t(context, 'docs', 'Documentation'),
              ),
              accent: const Color(0xFFEC4899),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              _t(
                context,
                'help_support_faq_title',
                'Frequently Asked Questions',
              ),
              eyebrow: 'Answers',
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.84),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colorScheme.outlineVariant.withValues(alpha: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: faqs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final faq = entry.value;
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: isDark ? 0.35 : 0.55,
                          ),
                        ),
                      _buildFaqItem(
                        context,
                        question: faq['question']!,
                        answer: faq['answer']!,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _buildFooterCta(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF121A2F),
                  colorScheme.primary.withValues(alpha: 0.16),
                  const Color(0xFF1C1430),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF6F3FF),
                  const Color(0xFFFFF3F8),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.20),
                  colorScheme.primary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              size: 28,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    context,
                    'help_support_hero_title',
                    'How can we help you?',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    context,
                    'help_support_hero_subtitle',
                    'Find answers or contact our support team',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterCta(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Text(
            _t(context, 'help_support_cta_title', 'Still need help?'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              context,
              'help_support_cta_subtitle',
              'Our support team is here to assist you',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _launchEmail(context),
            icon: const Icon(Icons.email_outlined),
            label: Text(_t(context, 'contact_support', 'Contact Support')),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(220, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    String? eyebrow,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.1,
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.04),
                  accent.withValues(alpha: 0.10),
                ]
              : [Colors.white, accent.withValues(alpha: 0.06)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.78),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.28 : 0.16),
                      accent.withValues(alpha: isDark ? 0.14 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.26 : 0.18),
                  ),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.north_east_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 0,
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        title: Text(
          question,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                answer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
