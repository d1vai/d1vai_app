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
    final faqs = _faqs(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'help_support', 'Help & Support')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 欢迎卡片
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 32,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 12),
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t(
                                context,
                                'help_support_hero_subtitle',
                                'Find answers or contact our support team',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 快速操作
          _buildSectionTitle(
            context,
            _t(context, 'help_support_quick_actions', 'Quick Actions'),
          ),
          const SizedBox(height: 12),

          _buildActionCard(
            context,
            icon: Icons.email,
            title: _t(context, 'contact_support', 'Contact Support'),
            subtitle: _t(
              context,
              'help_support_contact_subtitle',
              'Email us at {email}',
            ).replaceAll('{email}', supportEmail),
            onTap: () => _launchEmail(context),
          ),

          const SizedBox(height: 8),

          _buildActionCard(
            context,
            icon: Icons.menu_book,
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
          ),

          const SizedBox(height: 8),

          _buildActionCard(
            context,
            icon: Icons.description,
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
          ),

          const SizedBox(height: 24),

          // FAQ 部分
          _buildSectionTitle(
            context,
            _t(context, 'help_support_faq_title', 'Frequently Asked Questions'),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
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

          // 底部信息
          Center(
            child: Column(
              children: [
                Text(
                  _t(context, 'help_support_cta_title', 'Still need help?'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    context,
                    'help_support_cta_subtitle',
                    'Our support team is here to assist you',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _launchEmail(context),
                  icon: const Icon(Icons.email),
                  label: Text(
                    _t(context, 'contact_support', 'Contact Support'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
