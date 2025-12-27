import 'package:flutter/material.dart';

import '../../../models/message.dart';
import '../expandable_text.dart';
import 'message_card_base.dart';
import '../tools/tool_utils.dart';

class ChatErrorCard extends StatelessWidget {
  final ErrorMessageContent content;

  const ChatErrorCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = content.code != null ? 'Error ${content.code}' : 'Error';
    final detailsText =
        content.details != null ? prettyJson(content.details) : null;

    return ChatMessageCard(
      backgroundColor: theme.colorScheme.error.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: Icons.error_outline,
            iconColor: theme.colorScheme.error,
            title: title,
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: content.message,
            maxLines: 4,
            isMarkdown: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          if (detailsText != null && detailsText.isNotEmpty) ...[
            const SizedBox(height: 8),
            ChatExpandableSelectableBlock(
              text: detailsText,
              collapsedLines: 8,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.25,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatCompletionCard extends StatelessWidget {
  final CompletionMessageContent content;

  const ChatCompletionCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint =
        content.success ? chatSuccessTint(theme) : theme.colorScheme.error;
    final bg = tint.withValues(alpha: 0.10);

    return ChatMessageCard(
      backgroundColor: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (content.details != null && content.details!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpandableText(
              text: content.details!,
              maxLines: 4,
              isMarkdown: false,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatDeploymentCard extends StatelessWidget {
  final DeploymentMessageContent content;

  const ChatDeploymentCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = chatSuccessTint(theme);
    final warningTint = chatWarningTint(theme);
    final st = content.status.toLowerCase();
    final isSuccess = st == 'success';
    final isPending = st == 'pending';
    final isFailed = st == 'failed';

    final Color tint = isSuccess
        ? successTint
        : isPending
            ? warningTint
            : isFailed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant;

    final IconData icon = isSuccess
        ? Icons.check_circle
        : isPending
            ? Icons.hourglass_empty
            : isFailed
                ? Icons.error
                : Icons.info;

    return ChatMessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: icon,
            iconColor: tint,
            title:
                'Deployment${content.environment != null && content.environment!.isNotEmpty ? ' · ${content.environment}' : ''}',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                content.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          if (content.message != null && content.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content.message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          if (content.url != null && content.url!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: tint),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    content.url!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
