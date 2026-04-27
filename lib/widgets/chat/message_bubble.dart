import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'expandable_text.dart';
import 'message_bubble/alert_text_cards.dart';
import 'message_bubble/code_card.dart';
import 'message_bubble/git_cards.dart';
import 'message_bubble/result_cards.dart';
import 'message_bubble/status_cards.dart';
import 'message_bubble/thinking_card.dart';
import 'tools/enhanced_tool_message.dart';

/// Message bubble widget for displaying chat messages
/// Note: Message actions are available via long press
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final VoidCallback? onTap;
  final Widget? userAccessory;
  final bool highlightThinking;
  final List<MessageContent>? overrideContents;
  final bool plainLayout;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onTap,
    this.userAccessory,
    this.highlightThinking = false,
    this.overrideContents,
    this.plainLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = message.role;
    final contents = overrideContents ?? message.contents;
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...contents.map((content) {
          return _buildMessageContent(
            content,
            role,
            isUser,
            context,
            highlightThinking: highlightThinking,
          );
        }),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      // Long press is available for message actions (copy, etc.)
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: isUser && !plainLayout
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                          bottomLeft: Radius.circular(4.0),
                          bottomRight: Radius.circular(16.0),
                        ),
                      ),
                      child: contentColumn,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: contentColumn,
                    ),
            ),
            if (isUser && !plainLayout && userAccessory != null) ...[
              const SizedBox(width: 6.0),
              userAccessory!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    MessageContent content,
    String role,
    bool isUser,
    BuildContext context, {
    bool highlightThinking = false,
  }) {
    final theme = Theme.of(context);
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    if (content is TextMessageContent) {
      if (!isUser) {
        final r = role.toLowerCase().trim();
        if (r == 'warning') {
          return ChatAlertTextCard(
            kind: ChatAlertKind.warning,
            text: content.text,
          );
        }
        if (r == 'error') {
          return ChatAlertTextCard(
            kind: ChatAlertKind.error,
            text: content.text,
          );
        }

        final t = content.text.trim();
        if (t.startsWith('❌')) {
          return ChatAlertTextCard(
            kind: ChatAlertKind.error,
            text: content.text,
          );
        }
        if (t.contains('✅') || t.contains('❌')) {
          final lower = t.toLowerCase();
          if (lower.contains('finished') ||
              lower.contains('failed') ||
              lower.contains('success') ||
              lower.contains('error')) {
            return ChatCompletionTextCard(
              success: t.contains('✅') && !t.contains('❌'),
              text: content.text,
            );
          }
        }
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: ExpandableText(
          text: content.text,
          maxLines: 6,
          isMarkdown: !isUser,
          style: TextStyle(
            color: textColor,
            fontSize: isUser ? 14.0 : 13.0,
            height: 1.25,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
    } else if (content is ThinkingMessageContent) {
      return ChatThinkingCard(text: content.text, highlight: highlightThinking);
    } else if (content is CodeMessageContent) {
      return ChatCodeCard(
        code: content.code,
        isToolResult:
            isUser ||
            (content.subtype ?? '').toLowerCase().trim().startsWith(
              'tool_result',
            ),
      );
    } else if (content is ToolMessageContent) {
      return EnhancedToolMessage(content: content);
    } else if (content is GitCommitMessageContent) {
      return ChatGitCommitCard(content: content);
    } else if (content is GitPushMessageContent) {
      return ChatGitPushRow(content: content);
    } else if (content is ResultMessageContent) {
      return ChatResultCard(payload: content.payload);
    } else if (content is DeploymentMessageContent) {
      return ChatDeploymentCard(content: content);
    } else if (content is ErrorMessageContent) {
      return ChatErrorCard(content: content);
    } else if (content is CompletionMessageContent) {
      return ChatCompletionCard(content: content);
    } else if (content is RawMessageContent) {
      return ChatRawCard(payload: content.payload);
    }

    return const SizedBox.shrink();
  }
}
