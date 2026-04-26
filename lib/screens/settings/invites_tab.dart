import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/invite_code_display.dart';
import '../../widgets/snackbar_helper.dart';
import '../../widgets/login_required_view.dart';

/// Invites tab for the settings screen.
class SettingsInvitesTab extends StatelessWidget {
  const SettingsInvitesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final d1vaiService = D1vaiService();
    final loc = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) {
      return LoginRequiredView(
        message:
            loc?.translate('login_required_invites_message') ??
            'Please login first.',
        onAction: () => context.go('/login'),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: d1vaiService.getMyInvitees(),
      builder: (context, snapshot) {
        final friendCount = snapshot.hasData ? snapshot.data!.length : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final panelSurface = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
          scheme.surface,
        );
        final heroStart = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
          scheme.surface,
        );
        final heroEnd = Color.alphaBlend(
          scheme.secondary.withValues(alpha: isDark ? 0.16 : 0.10),
          scheme.surface,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomCard(
              padding: EdgeInsets.zero,
              backgroundColor: panelSurface,
              borderRadius: 22,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [heroStart, heroEnd],
                        ),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(
                            alpha: isDark ? 0.34 : 0.48,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(
                                    alpha: isDark ? 0.20 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.card_giftcard_rounded,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc?.translate('invite_friends') ??
                                          'Invite Friends',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      loc?.translate('invite_description') ??
                                          'Invite friends to join d1v.ai and get rewards',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            loc?.translate('your_invite_code') ??
                                'Your Invite Code',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ResponsiveInviteCodeDisplay(
                            inviteCode: user.inviteCode,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Button(
                                  onPressed: () async {
                                    if (user.inviteCode.isEmpty) return;
                                    await Clipboard.setData(
                                      ClipboardData(text: user.inviteCode),
                                    );
                                    if (!context.mounted) return;
                                    SnackBarHelper.showSuccess(
                                      context,
                                      title:
                                          loc?.translate('copied') ?? 'Copied',
                                      message:
                                          loc?.translate(
                                            'invite_code_copied',
                                          ) ??
                                          'Invite code copied to clipboard',
                                    );
                                  },
                                  variant: ButtonVariant.secondary,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                  ),
                                  text: loc?.translate('copy') ?? 'Copy',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Button(
                                  onPressed: () {
                                    _shareInviteCode(context);
                                  },
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                  ),
                                  text:
                                      loc?.translate('share_invite_code') ??
                                      'Share Invite Code',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricPanel(
                            icon: Icons.people_alt_outlined,
                            label:
                                loc?.translate('friends_referred') ??
                                'Friends Referred',
                            value: isLoading
                                ? (loc?.translate('loading') ?? 'Loading...')
                                : hasError
                                ? (loc?.translate('failed_to_load') ??
                                      'Failed to load')
                                : '$friendCount',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricPanel(
                            icon: Icons.history_toggle_off_rounded,
                            label: loc?.translate('my_invites') ?? 'My Invites',
                            value:
                                loc?.translate('my_invites_subtitle') ??
                                'View your invitation history',
                            alignStart: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: EdgeInsets.zero,
              backgroundColor: panelSurface,
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InviteActionRow(
                    icon: Icons.stacked_line_chart_rounded,
                    title: loc?.translate('my_invites') ?? 'My Invites',
                    subtitle:
                        loc?.translate('my_invites_subtitle') ??
                        'View your invitation history',
                    trailing: hasError
                        ? (loc?.translate('failed_to_load') ?? 'Failed to load')
                        : '$friendCount ${loc?.translate('friends_count') ?? 'friends'}',
                    onTap: () {
                      context.push('/settings/invites');
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? 0.32 : 0.56,
                    ),
                  ),
                  _InviteActionRow(
                    icon: Icons.refresh_rounded,
                    title:
                        loc?.translate('friends_referred') ??
                        'Friends Referred',
                    subtitle: hasError
                        ? (loc?.translate('failed_to_load') ?? 'Failed to load')
                        : isLoading
                        ? (loc?.translate('loading') ?? 'Loading...')
                        : '$friendCount ${loc?.translate('friends_count') ?? 'friends'}',
                    trailing: '',
                    compactTrailingIcon: Icons.arrow_forward_rounded,
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

class _MetricPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool alignStart;

  const _MetricPanel({
    required this.icon,
    required this.label,
    required this.value,
    this.alignStart = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.30 : 0.54,
          ),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.24 : 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: alignStart
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: alignStart ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignStart ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final IconData compactTrailingIcon;

  const _InviteActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.compactTrailingIcon = Icons.arrow_forward_ios_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                    scheme.surface,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing.isNotEmpty)
                Flexible(
                  child: Text(
                    trailing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Icon(
                compactTrailingIcon,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
              ),
            ],
          ),
        ),
      ),
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
