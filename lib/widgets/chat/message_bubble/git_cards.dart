import 'package:flutter/material.dart';

import '../../../models/message.dart';
import '../file_type_visual.dart';
import 'message_card_base.dart';

class ChatGitCommitCard extends StatelessWidget {
  final GitCommitMessageContent content;

  const ChatGitCommitCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = content.files ?? const <String>[];
    const fileTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11.5,
      height: 1.2,
    );
    final firstLineHeight =
        (fileTextStyle.fontSize ?? 11.5) * (fileTextStyle.height ?? 1.2);
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.35 : 0.6,
    );

    return ChatMessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: Icons.commit,
            iconColor: theme.colorScheme.primary,
            title: content.message.isNotEmpty ? content.message : 'Commit',
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${files.length} changed file${files.length == 1 ? '' : 's'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 3,
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final f in files)
                              Builder(
                                builder: (context) {
                                  final visual = fileTypeVisual(theme, f);
                                  final iconColor =
                                      (visual.color ??
                                              theme.colorScheme.onSurfaceVariant)
                                          .withValues(alpha: 0.85);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: firstLineHeight,
                                          child: Center(
                                            child: Icon(
                                              visual.icon,
                                              size: 14,
                                              color: iconColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: SelectableText(
                                            f,
                                            maxLines: 2,
                                            style: fileTextStyle.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatGitPushRow extends StatelessWidget {
  final GitPushMessageContent content;

  const ChatGitPushRow({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = chatSuccessTint(theme);
    final warningTint = chatWarningTint(theme);
    final isTimeout = content.error == 'timeout';
    final isSuccess = content.success && content.error == null;

    IconData icon;
    Color color;
    String label;

    if (isSuccess) {
      icon = Icons.check_circle;
      color = successTint;
      label = 'Git push succeeded';
    } else if (isTimeout) {
      icon = Icons.schedule;
      color = warningTint;
      label = 'Git push timeout';
    } else {
      icon = Icons.cancel;
      color = theme.colorScheme.error;
      label = 'Git push failed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (content.branch.isNotEmpty)
            Text(
              content.branch,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
