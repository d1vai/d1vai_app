import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';
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
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Coming Soon',
                        message: 'Notifications feature coming soon',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    subtitle: const Text('Get help and support'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Coming Soon',
                        message: 'Help feature coming soon',
                      );
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
                      _connectGithub();
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
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Your Invite Code',
                    hintText: 'Enter invite code',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        SnackBarHelper.showSuccess(
                          context,
                          title: 'Copied',
                          message: 'Invite code copied',
                        );
                      },
                    ),
                  ),
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
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Invite history feature coming soon',
                  );
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
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light Mode'),
                onTap: () {
                  Navigator.pop(context);
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Theme feature coming soon',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                onTap: () {
                  Navigator.pop(context);
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Theme feature coming soon',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                onTap: () {
                  Navigator.pop(context);
                  SnackBarHelper.showInfo(
                    context,
                    title: 'Coming Soon',
                    message: 'Theme feature coming soon',
                  );
                },
              ),
            ],
          ),
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

  /// 连接 GitHub
  void _connectGithub() {
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'GitHub integration feature coming soon',
    );
  }

  /// 分享邀请码
  void _shareInviteCode() {
    SnackBarHelper.showInfo(
      context,
      title: 'Coming Soon',
      message: 'Share feature coming soon',
    );
  }
}
