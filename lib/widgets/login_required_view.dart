import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import 'button.dart';
import 'card.dart';

enum LoginRequiredVariant { full, compactCard }

class LoginRequiredView extends StatelessWidget {
  final String? title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final LoginRequiredVariant variant;

  const LoginRequiredView({
    super.key,
    required this.message,
    this.title,
    this.actionText,
    this.onAction,
    this.variant = LoginRequiredVariant.full,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final t =
        title ?? (loc?.translate('login_required_title') ?? 'Login required');
    final a =
        actionText ?? (loc?.translate('login_required_button') ?? 'Login');

    final action = onAction ?? () => context.go('/login');

    final icon = Icon(
      Icons.lock_outline,
      size: variant == LoginRequiredVariant.full ? 56 : 22,
      color: Theme.of(context).colorScheme.primary,
    );

    if (variant == LoginRequiredVariant.compactCard) {
      return CustomCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Button(size: ButtonSize.sm, text: a, onPressed: action),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 16),
              Text(
                t,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Button(text: a, onPressed: action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
