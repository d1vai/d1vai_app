import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/d1vai_service.dart';
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
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentTab = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        foregroundColor: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
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
                    leading: const Icon(Icons.email),
                    title: const Text('Bind Email'),
                    subtitle: const Text('Bind email to your account'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showBindEmailDialog();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Reset Password'),
                    subtitle: const Text('Reset your login password'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showResetPasswordDialog();
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

                  Provider.of<ProjectProvider>(
                    context,
                    listen: false,
                  ).refresh().then((_) {
                    if (!mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Success',
                      message: 'Repositories synced successfully',
                    );
                  }).catchError((error) {
                    if (!mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Failed to sync repositories: $error',
                    );
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Import Repository'),
                subtitle: const Text('Import a public repository'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _showImportRepositoryDialog();
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
    final d1vaiService = D1vaiService();

    return FutureBuilder<List<dynamic>>(
      future: d1vaiService.getMyInvitees(),
      builder: (context, snapshot) {
        final friendCount = snapshot.hasData ? snapshot.data!.length : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

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
                    subtitle: isLoading
                        ? const Text('Loading...')
                        : hasError
                            ? const Text('Failed to load')
                            : Text('$friendCount friends'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.push('/settings/invites');
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
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

  /// 显示导入仓库对话框
  void _showImportRepositoryDialog() {
    final ownerController = TextEditingController();
    final repoController = TextEditingController();
    final projectNameController = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Public Repository'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the repository information you want to import',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ownerController,
                enabled: !isImporting,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  hintText: 'username or organization',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repoController,
                enabled: !isImporting,
                decoration: const InputDecoration(
                  labelText: 'Repository',
                  hintText: 'repository-name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: projectNameController,
                enabled: !isImporting,
                decoration: const InputDecoration(
                  labelText: 'Project Name (Optional)',
                  hintText: 'Leave empty to use repository name',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isImporting) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Importing...'),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isImporting
                  ? null
                  : () {
                      final owner = ownerController.text.trim();
                      final repo = repoController.text.trim();

                      if (owner.isEmpty || repo.isEmpty) {
                        SnackBarHelper.showError(
                          context,
                          title: 'Error',
                          message: 'Please enter owner and repository name',
                        );
                        return;
                      }

                      final dialogContext = context;

                      setDialogState(() {
                        isImporting = true;
                      });

                      D1vaiService().importPublicRepoToOrg({
                        'owner': owner,
                        'repo': repo,
                        if (projectNameController.text.trim().isNotEmpty)
                          'name': projectNameController.text.trim(),
                      }).then((_) {
                        if (!dialogContext.mounted) return;
                        SnackBarHelper.showSuccess(
                          dialogContext,
                          title: 'Success',
                          message: 'Repository imported successfully',
                        );

                        Navigator.pop(dialogContext);

                        if (!mounted) return;
                        Provider.of<ProjectProvider>(context, listen: false).refresh();
                      }).catchError((error) {
                        if (!dialogContext.mounted) return;
                        SnackBarHelper.showError(
                          dialogContext,
                          title: 'Error',
                          message: 'Failed to import repository: $error',
                        );
                        setDialogState(() {
                          isImporting = false;
                        });
                      });
                    },
              child: isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示绑定邮箱对话框
  void _showBindEmailDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    int step = 1; // 1: 输入邮箱, 2: 输入验证码
    final d1vaiService = D1vaiService();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bind Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step == 1
                    ? 'Enter your email address to receive a verification code'
                    : 'Enter the 6-digit verification code sent to your email',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (step == 1) ...[
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'your@email.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (step == 1) {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter an email address',
                    );
                    return;
                  }

                  // 验证邮箱格式
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(email)) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter a valid email address',
                    );
                    return;
                  }

                  try {
                    if (!context.mounted) return;
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Sending',
                      message: 'Sending verification code...',
                    );

                    await d1vaiService.postUserBindEmailSend(email);

                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Success',
                      message: 'Verification code sent to your email',
                    );
                    setDialogState(() {
                      step = 2;
                    });
                  } catch (error) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Failed to send verification code: $error',
                    );
                  }
                } else {
                  final code = codeController.text.trim();
                  if (code.isEmpty || code.length != 6) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter a 6-digit verification code',
                    );
                    return;
                  }

                  try {
                    if (!context.mounted) return;
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Verifying',
                      message: 'Verifying code...',
                    );

                    await d1vaiService.postUserBindEmailConfirm(
                      emailController.text.trim(),
                      code,
                    );

                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Success',
                      message: 'Email bound successfully',
                    );
                    Navigator.pop(context);

                    // 刷新用户信息
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.refreshUser();
                  } catch (error) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Failed to verify code: $error',
                    );
                  }
                }
              },
              child: Text(step == 1 ? 'Send Code' : 'Verify'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示重置密码对话框
  void _showResetPasswordDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int step = 1; // 1: 输入邮箱, 2: 输入验证码和新密码
    final d1vaiService = D1vaiService();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step == 1
                    ? 'Enter your email address to receive a verification code'
                    : 'Enter the verification code and your new password',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (step == 1) ...[
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'your@email.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter new password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (step == 1) {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter an email address',
                    );
                    return;
                  }

                  // 验证邮箱格式
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(email)) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter a valid email address',
                    );
                    return;
                  }

                  try {
                    if (!context.mounted) return;
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Sending',
                      message: 'Sending verification code...',
                    );

                    await d1vaiService.postUserPasswordForgotSend(email);

                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Success',
                      message: 'Verification code sent to your email',
                    );
                    setDialogState(() {
                      step = 2;
                    });
                  } catch (error) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Failed to send verification code: $error',
                    );
                  }
                } else {
                  final code = codeController.text.trim();
                  final newPassword = passwordController.text;
                  final confirmPassword = confirmPasswordController.text;

                  if (code.isEmpty || code.length != 6) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter a 6-digit verification code',
                    );
                    return;
                  }

                  if (newPassword.isEmpty) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Please enter a new password',
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Passwords do not match',
                    );
                    return;
                  }

                  if (newPassword.length < 6) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Password must be at least 6 characters',
                    );
                    return;
                  }

                  try {
                    if (!context.mounted) return;
                    SnackBarHelper.showInfo(
                      context,
                      title: 'Resetting',
                      message: 'Resetting password...',
                    );

                    await d1vaiService.postUserPasswordReset(
                      emailController.text.trim(),
                      code,
                      newPassword,
                    );

                    if (!context.mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Success',
                      message: 'Password reset successfully',
                    );
                    Navigator.pop(context);
                  } catch (error) {
                    if (!context.mounted) return;
                    SnackBarHelper.showError(
                      context,
                      title: 'Error',
                      message: 'Failed to reset password: $error',
                    );
                  }
                }
              },
              child: Text(step == 1 ? 'Send Code' : 'Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}
