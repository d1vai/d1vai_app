import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_security_dialog.dart';
import '../widgets/reset_password_dialog.dart';
import '../widgets/set_password_dialog.dart';

class EmailSecuritySettingsScreen extends StatefulWidget {
  const EmailSecuritySettingsScreen({super.key});

  @override
  State<EmailSecuritySettingsScreen> createState() => _EmailSecuritySettingsScreenState();
}

class _EmailSecuritySettingsScreenState extends State<EmailSecuritySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email & Security'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          final hasEmail = user?.email?.isNotEmpty == true;
          final hasPassword = user?.lastLoginType == 'password';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 邮箱管理卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            color: Colors.deepPurple,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Address',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasEmail
                                      ? 'Manage your email address'
                                      : 'Bind an email address to your account',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (hasEmail)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user?.email ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.verified,
                                    color: Colors.green.shade600,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bound Email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => EmailSecurityDialog(
                                currentEmail: hasEmail ? user?.email : null,
                                onSuccess: () {
                                  // 刷新用户信息
                                  authProvider.fetchUser();
                                },
                              ),
                            );
                          },
                          icon: Icon(hasEmail ? Icons.edit : Icons.add),
                          label: Text(hasEmail ? 'Change Email' : 'Bind Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 密码管理卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: Colors.deepPurple,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasPassword
                                      ? 'Reset your account password'
                                      : 'Set a password for your account',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (hasPassword) {
                              // 显示重置密码对话框
                              showDialog(
                                context: context,
                                builder: (context) => ResetPasswordDialog(
                                  initialEmail: user?.email ?? '',
                                  onSuccess: () {
                                    // 刷新用户信息
                                    authProvider.fetchUser();
                                  },
                                ),
                              );
                            } else {
                              // 显示设置密码对话框
                              showDialog(
                                context: context,
                                builder: (context) => SetPasswordDialog(
                                  onSuccess: () {
                                    // 刷新用户信息
                                    authProvider.fetchUser();
                                  },
                                ),
                              );
                            }
                          },
                          icon: Icon(hasPassword ? Icons.refresh : Icons.add),
                          label: Text(hasPassword ? 'Reset Password' : 'Set Password'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 安全提示卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Security Tips',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTipItem(
                        Icons.shield_outlined,
                        'Use a strong password with at least 6 characters',
                      ),
                      const SizedBox(height: 8),
                      _buildTipItem(
                        Icons.email_outlined,
                        'Bind your email to receive security notifications',
                      ),
                      const SizedBox(height: 8),
                      _buildTipItem(
                        Icons.verified_user_outlined,
                        'Enable two-factor authentication for extra security',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
