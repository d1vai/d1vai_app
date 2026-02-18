import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

Future<void> showInsufficientBalanceDialog(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final title =
      loc?.translate('billing_insufficient_title') ?? 'Insufficient Balance';
  final description =
      loc?.translate('billing_insufficient_description') ??
      'Your balance is insufficient for this action. Please top up first.';
  final later = loc?.translate('billing_insufficient_action_later') ?? 'Later';
  final topUp =
      loc?.translate('billing_insufficient_action_topup') ?? 'Top up now';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.go('/orders?tab=price');
              }
            },
            child: Text(topUp),
          ),
        ],
      );
    },
  );
}
