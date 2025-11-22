import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/avatar_image.dart';
import '../widgets/snackbar_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showLoginRequiredDialog();
      }
    });
  }

  /// 显示登录提示对话框
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('settings') ?? 'Settings'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.close),
        //     onPressed: () => context.pop(),
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // Tab 导航
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    0,
                    loc?.translate('profile') ?? 'Profile',
                    Icons.person,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton(1, 'GitHub', Icons.code)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton(2, 'Invites', Icons.group_add)),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildProfileTab(),
                _buildGithubTab(),
                _buildInvitesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 Tab 按钮
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentTab = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// 构建 Profile 标签
  Widget _buildProfileTab() {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, child) {
        final loc = AppLocalizations.of(context);
        final localeProvider = Provider.of<LocaleProvider>(context);
        final user = authProvider.user;

        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: AvatarImage(
                  key: ValueKey(user.picture), // 添加 key 以确保头像更新时重新构建
                  imageUrl: user.picture.isEmpty ? 'placeholder' : user.picture,
                  size: 40,
                  borderRadius: BorderRadius.circular(20),
                  fit: BoxFit.cover,
                ),
                title: Text(
                  user.companyName.isNotEmpty ? user.companyName : 'User',
                ),
                subtitle: Text(user.email ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  context.push('/profile');
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6),
                    title: const Text('Theme'),
                    subtitle: const Text('Light or Dark mode'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showThemeDialog();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(loc?.translate('language') ?? 'Language'),
                    subtitle: Text(localeProvider.currentLanguageName),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.push('/settings/language');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notifications'),
                    subtitle: const Text('Manage notifications'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.push('/settings/notifications');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    subtitle: const Text('Get help and support'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.push('/settings/help');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About'),
                    subtitle: const Text('App version and info'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );

                  // 立即显示加载提示
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Logging out',
                    message: '正在退出登录...',
                  );

                  // 异步执行登出（不等待）
                  authProvider.logout().then((_) {
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }).catchError((e) {
                    if (context.mounted) {
                      SnackBarHelper.showError(
                        context,
                        title: 'Error',
                        message: '退出登录失败: $e',
                      );
                    }
                  });
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  loc?.translate('logout') ?? 'Logout',
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建 GitHub 标签
  Widget _buildGithubTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, color: Colors.deepPurple, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GitHub Integration',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your GitHub account to import repositories',
                            style: Theme.of(context).textTheme.bodySmall
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
                      context.push('/settings/github');
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Connect GitHub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Sync Repositories'),
                subtitle: const Text('Update your repository list'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Syncing',
                    message: 'Syncing repositories...',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Import Repository'),
                subtitle: const Text('Import a public repository'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Import feature coming soon',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建 Invites 标签
  Widget _buildInvitesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite Friends',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite friends to join d1v.ai and get rewards',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final user = authProvider.user;
                    final inviteCode = user?.inviteCode ?? 'Loading...';

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListTile(
                        title: Text(
                          inviteCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        subtitle: const Text('Your Invite Code'),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            if (inviteCode.isNotEmpty && inviteCode != 'Loading...') {
                              SnackBarHelper.showSuccess(
                                context,
                                title: 'Copied',
                                message: 'Invite code copied to clipboard',
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _shareInviteCode();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Invite Code'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: const Text('My Invites'),
                subtitle: const Text('View your invitation history'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  context.push('/settings/invites');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Friends Referred'),
                subtitle: const Text('0 friends'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Referral feature coming soon',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示主题选择对话框
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return AlertDialog(
              title: const Text('Choose Theme'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.light,
                    Icons.light_mode,
                    'Light Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.dark,
                    Icons.dark_mode,
                    'Dark Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.system,
                    Icons.brightness_auto,
                    'System',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    AppThemeMode mode,
    IconData icon,
    String title,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.deepPurple : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.deepPurple : null,
        ),
      ),
      trailing: Radio<AppThemeMode>(
        // ignore: deprecated_member_use
        groupValue: themeProvider.themeMode,
        // ignore: deprecated_member_use
        onChanged: (AppThemeMode? newMode) {
          if (newMode != null) {
            Navigator.pop(context);
            themeProvider.setThemeMode(newMode);
            SnackBarHelper.showSuccess(
              context,
              title: 'Theme Updated',
              message: 'Switched to $title',
            );
          }
        },
        value: mode,
      ),
      onTap: () {
        Navigator.pop(context);
        themeProvider.setThemeMode(mode);
        SnackBarHelper.showSuccess(
          context,
          title: 'Theme Updated',
          message: 'Switched to $title',
        );
      },
    );
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'd1v.ai',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.apps, size: 48),
      children: [const Text('An AI-powered app development platform.')],
    );
  }

  /// 分享邀请码
  Future<void> _shareInviteCode() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Please login first',
        );
      }
      return;
    }

    final inviteCode = user.inviteCode;
    if (inviteCode.isEmpty) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Invite code not available',
        );
      }
      return;
    }

    final inviteLink = 'https://d1v.ai/login?invite=$inviteCode';

    final message = '''Join me on d1v.ai! 🚀

Use my invite code: $inviteCode

Click the link to get started:
$inviteLink

Together, let's build the future of AI-powered applications!''';

    try {
      await Share.share(
        message,
        subject: 'Join me on d1v.ai',
      );
      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          title: 'Shared',
          message: 'Invite code shared successfully',
        );
      }
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to share: $error',
        );
      }
    }
  }
}
