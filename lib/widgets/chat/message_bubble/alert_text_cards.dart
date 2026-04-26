import 'package:flutter/material.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';

import '../expandable_text.dart';
import 'message_card_base.dart';

enum ChatAlertKind { error, warning }

class ChatAlertTextCard extends StatelessWidget {
  final ChatAlertKind kind;
  final String text;

  const ChatAlertTextCard({super.key, required this.kind, required this.text});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final Color tint = switch (kind) {
      ChatAlertKind.error => theme.colorScheme.error,
      ChatAlertKind.warning => chatWarningTint(theme),
    };

    final String title = switch (kind) {
      ChatAlertKind.error => loc?.translate('alert_title_error') ?? 'Error',
      ChatAlertKind.warning =>
        loc?.translate('alert_title_warning') ?? 'Warning',
    };

    return ChatMessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: text,
            maxLines: 3,
            isMarkdown: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tint.withValues(alpha: 0.92),
              height: 1.3,
              fontSize: 12.8,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatCompletionTextCard extends StatelessWidget {
  final bool success;
  final String text;

  const ChatCompletionTextCard({
    super.key,
    required this.success,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color tint = success
        ? chatSuccessTint(theme)
        : theme.colorScheme.error;

    return ChatMessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ExpandableText(
              text: text,
              maxLines: 3,
              isMarkdown: false,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                height: 1.25,
                fontSize: 12.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
