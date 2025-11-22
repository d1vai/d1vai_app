import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/snackbar_helper.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // FAQ 数据
  static const List<Map<String, String>> faqs = [
    {
      'question': 'How do I create a new project?',
      'answer':
          'Navigate to the Projects tab and tap the "+" button. You can either create a new project from scratch or import from GitHub.',
    },
    {
      'question': 'How do I connect my GitHub account?',
      'answer':
          'Go to Settings > GitHub tab. Enter your Personal Access Token with the required permissions (repo, read:user, user:email, read:org, workflow).',
    },
    {
      'question': 'What payment methods are supported?',
      'answer':
          'We currently support credit/debit cards through Stripe. More payment methods will be added in future updates.',
    },
    {
      'question': 'How do I invite friends?',
      'answer':
          'Go to Settings > Invites tab. You can share your unique invite code or invitation link. You can invite up to 3 users within a 7-day window.',
    },
    {
      'question': 'Can I change my email address?',
      'answer':
          'Yes! Go to Settings > Profile tab and tap on the email field. You\'ll need to verify your new email address.',
    },
    {
      'question': 'How do I reset my password?',
      'answer':
          'In Settings > Profile tab, tap on "Reset Password". You\'ll receive a verification code via email to complete the process.',
    },
    {
      'question': 'What is the difference between Light and Dark mode?',
      'answer':
          'Light mode uses a bright theme ideal for daytime use. Dark mode uses a darker theme that\'s easier on the eyes in low-light conditions. You can also set it to follow your system settings.',
    },
    {
      'question': 'How do I delete my account?',
      'answer':
          'Please contact our support team at support@d1v.ai to request account deletion. We\'ll process your request within 48 hours.',
    },
  ];

  // 联系支持邮箱
  static const String supportEmail = 'support@d1v.ai';

  // 文档链接
  static const String docsUrl = 'https://docs.d1v.ai';

  // 用户指南链接
  static const String userGuideUrl = 'https://docs.d1v.ai/user-guide';

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
            title: 'Error',
            message: 'Could not open email app. Please email us at $supportEmail',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to open email: $e',
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
            title: 'Error',
            message: 'Could not open $name',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to open $name: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
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
                              'How can we help you?',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find answers or contact our support team',
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
          _buildSectionTitle(context, 'Quick Actions'),
          const SizedBox(height: 12),

          _buildActionCard(
            context,
            icon: Icons.email,
            title: 'Contact Support',
            subtitle: 'Email us at $supportEmail',
            onTap: () => _launchEmail(context),
          ),

          const SizedBox(height: 8),

          _buildActionCard(
            context,
            icon: Icons.menu_book,
            title: 'User Guide',
            subtitle: 'Learn how to use all features',
            onTap: () => _launchUrl(context, userGuideUrl, 'User Guide'),
          ),

          const SizedBox(height: 8),

          _buildActionCard(
            context,
            icon: Icons.description,
            title: 'Documentation',
            subtitle: 'Technical documentation and API reference',
            onTap: () => _launchUrl(context, docsUrl, 'Documentation'),
          ),

          const SizedBox(height: 24),

          // FAQ 部分
          _buildSectionTitle(context, 'Frequently Asked Questions'),
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
                  'Still need help?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Our support team is here to assist you',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _launchEmail(context),
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Support'),
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
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
