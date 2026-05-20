import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/theme_provider.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/services/d1vai_service.dart';
import 'package:d1vai_app/widgets/adaptive_modal.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';
import 'package:d1vai_app/widgets/button.dart';
import 'package:d1vai_app/core/theme/app_colors.dart';
import 'package:d1vai_app/core/theme/locale_font_helper.dart';
import 'package:d1vai_app/screens/settings/profile_tab.dart';
import 'package:d1vai_app/screens/settings/github_tab.dart';
import 'package:d1vai_app/screens/settings/invites_tab.dart';
import 'package:d1vai_app/screens/settings/api_keys_tab.dart';
import 'package:d1vai_app/utils/desktop_layout.dart';
import 'package:d1vai_app/widgets/editor_preferences_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialTab;

  const SettingsScreen({super.key, this.initialTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentTab = 0;

  int _tabIndexFromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'invites':
        return 1;
      case 'github':
        return 2;
      case 'api-key':
      case 'api_key':
      case 'apikey':
        return 3;
      case 'profile':
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentTab = _tabIndexFromValue(widget.initialTab);
    // 不在这里直接根据一次性的 user 快照判断是否登录，
    // 而是在 build 中结合 AuthProvider 的 isLoading / user 状态做判断，
    // 避免刚进入页面时 Auth 还在初始化导致误弹登录弹窗。
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      final nextTab = _tabIndexFromValue(widget.initialTab);
      if (nextTab != _currentTab) {
        setState(() {
          _currentTab = nextTab;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final desktop = isDesktopLayout(context);
    final tabs = [
      (
        label: loc?.translate('profile') ?? 'Profile',
        icon: Icons.person,
        child: SettingsProfileTab(
          onShowThemeDialog: _showThemeDialog,
          onShowEditorPreferencesDialog: _showEditorPreferencesDialog,
          onShowBindEmailDialog: _showBindEmailDialog,
          onShowResetPasswordDialog: _showResetPasswordDialog,
          onShowAboutDialog: _showAboutDialog,
        ),
      ),
      (
        label: loc?.translate('invites') ?? 'Invites',
        icon: Icons.group_add,
        child: const SettingsInvitesTab(),
      ),
      (
        label: loc?.translate('github') ?? 'GitHub',
        icon: Icons.code,
        child: const SettingsGithubTab(),
      ),
      (
        label: loc?.translate('settings_api_key') ?? 'API Key',
        icon: Icons.key_rounded,
        child: const SettingsApiKeysTab(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc?.translate('settings') ?? 'Settings',
          style: LocaleFontHelper.localizedTitleStyle(
            context,
            Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      body: desktop
          ? DesktopContentFrame(
              maxWidth: 1380,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < tabs.length; i++) ...[
                          _buildDesktopTabButton(
                            i,
                            tabs[i].label,
                            tabs[i].icon,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTab,
                      children: tabs.map((tab) => tab.child).toList(),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(0, tabs[0].label, tabs[0].icon),
                      const SizedBox(width: 8),
                      _buildTabButton(1, tabs[1].label, tabs[1].icon),
                      const SizedBox(width: 8),
                      _buildTabButton(2, tabs[2].label, tabs[2].icon),
                      const SizedBox(width: 8),
                      _buildTabButton(3, tabs[3].label, tabs[3].icon),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: tabs.map((tab) => tab.child).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  void _showEditorPreferencesDialog() {
    showAdaptiveModal(
      context: context,
      builder: (_) => const EditorPreferencesDialogBody(),
    );
  }

  /// 构建 Tab 按钮
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;

    return Expanded(
      child: Button(
        variant: isSelected
            ? ButtonVariant.defaultVariant
            : ButtonVariant.ghost,
        size: ButtonSize.sm,
        text: label,
        icon: Icon(icon, size: 16),
        onPressed: () {
          setState(() {
            _currentTab = index;
          });
        },
      ),
    );
  }

  Widget _buildDesktopTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = index;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : colorScheme.surfaceContainerLow,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.18)
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示主题选择对话框
  void _showThemeDialog() {
    final loc = AppLocalizations.of(context);
    showAdaptiveModal(
      context: context,
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return AdaptiveModalContainer(
              maxWidth: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdaptiveModalHeader(
                    title: loc?.translate('choose_theme') ?? 'Choose Theme',
                    subtitle: 'Match your workspace mood and ambient contrast.',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.light,
                    Icons.light_mode,
                    loc?.translate('light_mode') ?? 'Light Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.dark,
                    Icons.dark_mode,
                    loc?.translate('dark_mode') ?? 'Dark Mode',
                  ),
                  _buildThemeOption(
                    context,
                    themeProvider,
                    AppThemeMode.system,
                    Icons.brightness_auto,
                    loc?.translate('system_mode') ?? 'System',
                  ),
                  const SizedBox(height: 8),
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
      leading: Icon(icon, color: isSelected ? AppColors.primaryBrand : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryBrand : null,
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
        final loc = AppLocalizations.of(context);
        Navigator.pop(context);
        themeProvider.setThemeMode(mode);
        SnackBarHelper.showSuccess(
          context,
          title: loc?.translate('theme_updated') ?? 'Theme Updated',
          message:
              '${loc?.translate('theme_switched') ?? 'Switched to'} $title',
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
      children: [
        Text(
          AppLocalizations.of(context)?.translate('about_description') ??
              'An AI-powered app development platform.',
        ),
      ],
    );
  }

  /// 显示绑定邮箱对话框
  void _showBindEmailDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    int step = 1; // 1: 输入邮箱, 2: 输入验证码
    final d1vaiService = D1vaiService();

    final loc = AppLocalizations.of(context);

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: loc?.translate('bind_email') ?? 'Bind Email',
                  subtitle: step == 1
                      ? (loc?.translate('enter_email_for_code') ??
                            'Enter your email address to receive a verification code')
                      : (loc?.translate('enter_code_sent') ??
                            'Enter the 6-digit verification code sent to your email'),
                  onClose: () => Navigator.pop(context),
                ),
                if (step == 1) ...[
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: loc?.translate('email') ?? 'Email',
                      hintText: 'your@email.com',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ] else ...[
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('verify_code') ?? 'Verification Code',
                      hintText: '123456',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc?.translate('cancel') ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (step == 1) {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('email_required') ??
                                    'Please enter an email address',
                              );
                              return;
                            }

                            // 验证邮箱格式
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(email)) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('email_invalid') ??
                                    'Please enter a valid email address',
                              );
                              return;
                            }

                            try {
                              if (!context.mounted) return;
                              SnackBarHelper.showInfo(
                                context,
                                title: loc?.translate('sending') ?? 'Sending',
                                message:
                                    loc?.translate('sending') ??
                                    'Sending verification code...',
                              );

                              await d1vaiService.postUserBindEmailSend(email);

                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('code_sent_success') ??
                                    'Verification code sent to your email',
                              );
                              setDialogState(() {
                                step = 2;
                              });
                            } catch (error) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_send_code') ?? "Failed to send verification code"}: $error',
                              );
                            }
                          } else {
                            final code = codeController.text.trim();
                            if (code.isEmpty || code.length != 6) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('verify_code_complete') ??
                                    'Please enter a 6-digit verification code',
                              );
                              return;
                            }

                            try {
                              if (!context.mounted) return;
                              SnackBarHelper.showInfo(
                                context,
                                title:
                                    loc?.translate('verifying') ?? 'Verifying',
                                message:
                                    loc?.translate('verifying') ??
                                    'Verifying code...',
                              );

                              await d1vaiService.postUserBindEmailConfirm(
                                emailController.text.trim(),
                                code,
                              );

                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('email_bound_success') ??
                                    'Email bound successfully',
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
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_verify') ?? "Failed to verify code"}: $error',
                              );
                            }
                          }
                        },
                        child: Text(
                          step == 1
                              ? (loc?.translate('send_code') ?? 'Send Code')
                              : (loc?.translate('confirm') ?? 'Verify'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示重置密码对话框
  void _showResetPasswordDialog() {
    final loc = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int step = 1; // 1: 输入邮箱, 2: 输入验证码和新密码
    final d1vaiService = D1vaiService();

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: loc?.translate('reset_password') ?? 'Reset Password',
                  subtitle: step == 1
                      ? (loc?.translate('enter_email_for_code') ??
                            'Enter your email address to receive a verification code')
                      : (loc?.translate('enter_code_and_new_password') ??
                            'Enter the verification code and your new password'),
                  onClose: () => Navigator.pop(context),
                ),
                if (step == 1) ...[
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: loc?.translate('email') ?? 'Email',
                      hintText: 'your@email.com',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ] else ...[
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('verify_code') ?? 'Verification Code',
                      hintText: '123456',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('new_password') ?? 'New Password',
                      hintText:
                          loc?.translate('enter_new_password') ??
                          'Enter new password',
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('confirm_password') ??
                          'Confirm Password',
                      hintText:
                          loc?.translate('re_enter_new_password') ??
                          'Re-enter new password',
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc?.translate('cancel') ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (step == 1) {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('email_required') ??
                                    'Please enter an email address',
                              );
                              return;
                            }

                            // 验证邮箱格式
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(email)) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('email_invalid') ??
                                    'Please enter a valid email address',
                              );
                              return;
                            }

                            try {
                              if (!context.mounted) return;
                              SnackBarHelper.showInfo(
                                context,
                                title: loc?.translate('sending') ?? 'Sending',
                                message:
                                    loc?.translate('sending') ??
                                    'Sending verification code...',
                              );

                              await d1vaiService.postUserPasswordForgotSend(
                                email,
                              );

                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('code_sent_success') ??
                                    'Verification code sent to your email',
                              );
                              setDialogState(() {
                                step = 2;
                              });
                            } catch (error) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_send_code') ?? "Failed to send verification code"}: $error',
                              );
                            }
                          } else {
                            final code = codeController.text.trim();
                            final newPassword = passwordController.text;
                            final confirmPassword =
                                confirmPasswordController.text;

                            if (code.isEmpty || code.length != 6) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('verify_code_complete') ??
                                    'Please enter a 6-digit verification code',
                              );
                              return;
                            }

                            if (newPassword.isEmpty) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('password_required') ??
                                    'Please enter a new password',
                              );
                              return;
                            }

                            if (newPassword != confirmPassword) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('passwords_do_not_match') ??
                                    'Passwords do not match',
                              );
                              return;
                            }

                            if (newPassword.length < 6) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    loc?.translate('password_length_error') ??
                                    'Password must be at least 6 characters',
                              );
                              return;
                            }

                            try {
                              if (!context.mounted) return;
                              SnackBarHelper.showInfo(
                                context,
                                title:
                                    loc?.translate('resetting') ?? 'Resetting',
                                message:
                                    loc?.translate('resetting') ??
                                    'Resetting password...',
                              );

                              await d1vaiService.postUserPasswordReset(
                                emailController.text.trim(),
                                code,
                                newPassword,
                              );

                              if (!context.mounted) return;
                              SnackBarHelper.showSuccess(
                                context,
                                title: loc?.translate('success') ?? 'Success',
                                message:
                                    loc?.translate('password_reset_success') ??
                                    'Password reset successfully',
                              );
                              Navigator.pop(context);
                            } catch (error) {
                              if (!context.mounted) return;
                              SnackBarHelper.showError(
                                context,
                                title: loc?.translate('error') ?? 'Error',
                                message:
                                    '${loc?.translate('failed_to_reset_password') ?? "Failed to reset password"}: $error',
                              );
                            }
                          }
                        },
                        child: Text(
                          step == 1
                              ? (loc?.translate('send_code') ?? 'Send Code')
                              : (loc?.translate('reset_password') ??
                                    'Reset Password'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
