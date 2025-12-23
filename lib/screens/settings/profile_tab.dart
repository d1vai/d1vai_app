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

        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: AvatarImage(
                  // Ensure avatar updates when picture changes.
                  key: ValueKey(user.picture),
                  imageUrl: user.picture.isEmpty ? 'placeholder' : user.picture,
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
                    title: const Text('Theme'),
                    subtitle: const Text('Light or Dark mode'),
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
                    title: const Text('Notifications'),
                    subtitle: const Text('Manage notifications'),
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
                    title: const Text('Bind Email'),
                    subtitle: const Text('Bind email to your account'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: onShowBindEmailDialog,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: AppColors.error),
                    title: const Text('Reset Password'),
                    subtitle: const Text('Reset your login password'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: onShowResetPasswordDialog,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.help, color: AppColors.success),
                    title: const Text('Help & Support'),
                    subtitle: const Text('Get help and support'),
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
                    leading: const Icon(Icons.settings_ethernet, color: AppColors.info),
                    title: const Text('API'),
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
                    title: const Text('About'),
                    subtitle: const Text('App version and info'),
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
