import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import 'button.dart';

/// 登录提示对话框组件
class LoginRequiredDialog extends StatelessWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onCancel;
  final String? title;
  final String? message;

  const LoginRequiredDialog({
    super.key,
    this.onLogin,
    this.onCancel,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);

    final t =
        title ?? (loc?.translate('login_required_title') ?? 'Login required');
    final m =
        message ??
        (loc?.translate('login_required_orders_message') ??
            'This feature requires you to be logged in. Please login to continue.');

    void handleCancel() {
      (onCancel ?? () => Navigator.of(context).pop()).call();
    }

    void handleLogin() {
      if (onLogin != null) {
        onLogin!.call();
        return;
      }
      Navigator.of(context).pop();
      context.go('/login');
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 30,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t,
              style:
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ) ??
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              m,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.25,
                  ) ??
                  TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.25,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Button(
                    variant: ButtonVariant.outline,
                    text: loc?.translate('cancel') ?? 'Cancel',
                    onPressed: handleCancel,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Button(
                    text: loc?.translate('login_required_button') ?? 'Login',
                    onPressed: handleLogin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
