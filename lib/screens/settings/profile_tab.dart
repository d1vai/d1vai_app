import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/api_client.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/login_required_view.dart';

/// Profile tab for the settings screen.
class SettingsProfileTab extends StatelessWidget {
  const SettingsProfileTab({
    super.key,
    required this.onShowThemeDialog,
    required this.onShowBindEmailDialog,
    required this.onShowResetPasswordDialog,
    required this.onShowAboutDialog,
  });

  final VoidCallback onShowThemeDialog;
  final VoidCallback onShowBindEmailDialog;
  final VoidCallback onShowResetPasswordDialog;
  final VoidCallback onShowAboutDialog;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, child) {
        final loc = AppLocalizations.of(context);
        final localeProvider = Provider.of<LocaleProvider>(context);
        final user = authProvider.user;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user == null)
              LoginRequiredView(
                variant: LoginRequiredVariant.compactCard,
                message:
                    loc?.translate('login_required_settings_message') ??
                    'Please login first.',
                onAction: () => context.go('/login'),
              )
            else
              CustomCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: AvatarImage(
                    // Ensure avatar updates when picture changes.
                    key: ValueKey(user.picture),
                    imageUrl:
                        user.picture.isEmpty ? 'placeholder' : user.picture,
                    size: 40,
                    borderRadius: BorderRadius.circular(20),
                    fit: BoxFit.cover,
                  ),
                  title: Text(
                    user.companyName.isNotEmpty ? user.companyName : 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    user.email ?? '',
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondaryLight,
                  ),
                  onTap: () {
                    context.push('/profile');
                  },
                ),
              ),
            const SizedBox(height: 16),
            CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.brightness_6,
                      color: AppColors.primaryBrand,
                    ),
                    title: Text(loc?.translate('theme_title') ?? 'Theme'),
                    subtitle: Text(
                      loc?.translate('theme_subtitle') ?? 'Light or Dark mode',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: onShowThemeDialog,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderSubtleDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.language, color: AppColors.info),
                    title: Text(loc?.translate('language') ?? 'Language'),
                    subtitle: Text(localeProvider.currentLanguageName),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      context.push('/settings/language');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications,
                      color: AppColors.warning,
                    ),
                    title: Text(
                      loc?.translate('notifications') ?? 'Notifications',
                    ),
                    subtitle: Text(
                      loc?.translate('notifications_subtitle') ??
                          'Manage notifications',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      context.push('/settings/notifications');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.email,
                      color: AppColors.secondaryBrand,
                    ),
                    title: Text(loc?.translate('bind_email') ?? 'Bind Email'),
                    subtitle: Text(
                      loc?.translate('bind_email_subtitle') ??
                          'Bind email to your account',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: user == null ? () => context.go('/login') : onShowBindEmailDialog,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: AppColors.error),
                    title: Text(
                      loc?.translate('reset_password') ?? 'Reset Password',
                    ),
                    subtitle: Text(
                      loc?.translate('reset_password_subtitle') ??
                          'Reset your login password',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: user == null ? () => context.go('/login') : onShowResetPasswordDialog,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.help, color: AppColors.success),
                    title: Text(
                      loc?.translate('help_support') ?? 'Help & Support',
                    ),
                    subtitle: Text(
                      loc?.translate('help_support_subtitle') ??
                          'Get help and support',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      context.push('/settings/help');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_ethernet,
                      color: AppColors.info,
                    ),
                    title: Text(loc?.translate('api_settings') ?? 'API'),
                    subtitle: Text(ApiClient.baseUrl),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      context.push('/settings/api');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info,
                      color: AppColors.textSecondaryLight,
                    ),
                    title: Text(loc?.translate('about_title') ?? 'About'),
                    subtitle: Text(
                      loc?.translate('about_subtitle') ??
                          'App version and info',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: onShowAboutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Button(
                variant: ButtonVariant.ghost,
                foregroundColor: AppColors.error,
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await authProvider.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                // Custom child so icon and text stay visually tight.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, size: 16),
                    const SizedBox(width: 4),
                    Text(loc?.translate('logout') ?? 'Logout'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
