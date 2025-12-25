import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/snackbar_helper.dart';

/// Invites tab for the settings screen.
class SettingsInvitesTab extends StatelessWidget {
  const SettingsInvitesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final d1vaiService = D1vaiService();
    final loc = AppLocalizations.of(context);

    return FutureBuilder<List<dynamic>>(
      future: d1vaiService.getMyInvitees(),
      builder: (context, snapshot) {
        final friendCount = snapshot.hasData ? snapshot.data!.length : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc?.translate('invite_friends') ?? 'Invite Friends',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc?.translate('invite_description') ??
                          'Invite friends to join d1v.ai and get rewards',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final user = authProvider.user;
                        final inviteCode =
                            user?.inviteCode ??
                            (loc?.translate('loading') ?? 'Loading...');

                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
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
                            subtitle: Text(
                              loc?.translate('your_invite_code') ??
                                  'Your Invite Code',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                if (inviteCode.isNotEmpty &&
                                    inviteCode != 'Loading...') {
                                  SnackBarHelper.showSuccess(
                                    context,
                                    title: loc?.translate('copied') ?? 'Copied',
                                    message:
                                        loc?.translate('invite_code_copied') ??
                                        'Invite code copied to clipboard',
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
                      child: Button(
                        onPressed: () {
                          _shareInviteCode(context);
                        },
                        icon: const Icon(Icons.share),
                        text:
                            loc?.translate('share_invite_code') ??
                            'Share Invite Code',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.card_giftcard,
                      color: AppColors.secondaryBrand,
                    ),
                    title: Text(loc?.translate('my_invites') ?? 'My Invites'),
                    subtitle: Text(
                      loc?.translate('my_invites_subtitle') ??
                          'View your invitation history',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    onTap: () {
                      context.push('/settings/invites');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, color: AppColors.success),
                    title: Text(
                      loc?.translate('friends_referred') ?? 'Friends Referred',
                    ),
                    subtitle: isLoading
                        ? Text(loc?.translate('loading') ?? 'Loading...')
                        : hasError
                        ? Text(
                            loc?.translate('failed_to_load') ??
                                'Failed to load',
                          )
                        : Text(
                            '$friendCount ${loc?.translate('friends_count') ?? 'friends'}',
                          ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
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
}

Future<void> _shareInviteCode(BuildContext context) async {
  final user = Provider.of<AuthProvider>(context, listen: false).user;
  final loc = AppLocalizations.of(context);
  if (user == null) {
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        title: loc?.translate('error') ?? 'Error',
        message: loc?.translate('login_first') ?? 'Please login first',
      );
    }
    return;
  }

  final inviteCode = user.inviteCode;
  if (inviteCode.isEmpty) {
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        title: loc?.translate('error') ?? 'Error',
        message:
            loc?.translate('invite_code_unavailable') ??
            'Invite code not available',
      );
    }
    return;
  }

  final inviteLink = 'https://d1v.ai/login?invite=$inviteCode';

  final message =
      '''Join me on d1v.ai! 🚀

Use my invite code: $inviteCode

Click the link to get started:
$inviteLink

Together, let's build the future of AI-powered applications!''';

  try {
    await Share.share(
      message,
      subject: loc?.translate('share_message_subject') ?? 'Join me on d1v.ai',
    );
    if (context.mounted) {
      SnackBarHelper.showSuccess(
        context,
        title: loc?.translate('success') ?? 'Success',
        message:
            loc?.translate('share_success') ??
            'Invite code shared successfully',
      );
    }
  } catch (error) {
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        title: loc?.translate('error') ?? 'Error',
        message:
            '${loc?.translate('share_failed') ?? "Failed to share"}: $error',
      );
    }
  }
}
