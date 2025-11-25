import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';
import 'expandable_text.dart';
import 'tools/enhanced_tool_message.dart';

/// Message bubble widget for displaying chat messages
/// Note: Message actions are available via long press
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final VoidCallback? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Long press is available for message actions (copy, etc.)
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              _buildAvatar(context),
              const SizedBox(width: 8.0),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16.0),
                    topRight: const Radius.circular(16.0),
                    bottomLeft: isUser
                        ? const Radius.circular(16.0)
                        : const Radius.circular(4.0),
                    bottomRight: isUser
                        ? const Radius.circular(4.0)
                        : const Radius.circular(16.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...message.contents.map((content) {
                      return _buildMessageContent(content, isUser, context);
                    }),
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8.0),
              _buildAvatar(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16.0,
      backgroundColor: isUser
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 18.0,
        color: isUser
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildMessageContent(
    MessageContent content,
    bool isUser,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    if (content is TextMessageContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: ExpandableText(
          text: content.text,
          maxLines: 6,
          style: TextStyle(
            color: textColor,
            fontSize: 16.0,
          ),
        ),
      );
    } else if (content is ThinkingMessageContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 16.0,
              color: textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Text(
                content.text,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (content is CodeMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
IconButton(
                  icon: const Icon(Icons.copy, size: 16.0),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: content.code),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24.0,
                    minHeight: 24.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                content.code,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'monospace',
                  fontSize: 14.0,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (content is ToolMessageContent) {
      return EnhancedToolMessage(content: content);
    } else if (content is GitCommitMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.commit,
                  size: 16.0,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Git Commit',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              content.message,
              style: TextStyle(
                color: textColor,
                fontSize: 13.0,
              ),
            ),
            if (content.files != null && content.files!.isNotEmpty) ...[
              const SizedBox(height: 4.0),
              Text(
                '${content.files!.length} files changed',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is GitPushMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: content.success
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: content.success
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  content.success ? Icons.check_circle : Icons.error,
                  size: 16.0,
                  color: content.success ? theme.colorScheme.primary : theme.colorScheme.error,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Git Push to ${content.branch}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            if (content.error != null) ...[
              const SizedBox(height: 4.0),
              Text(
                content.error!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is ResultMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16.0,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Result',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            if (content.payload != null) ...[
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SelectableText(
                  content.payload.toString(),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 13.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is DeploymentMessageContent) {
      final isSuccess = content.status.toLowerCase() == 'success';
      final isPending = content.status.toLowerCase() == 'pending';
      final isFailed = content.status.toLowerCase() == 'failed';

      Color statusColor;
      IconData statusIcon;

      if (isSuccess) {
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.check_circle;
      } else if (isPending) {
        statusColor = theme.colorScheme.tertiary;
        statusIcon = Icons.hourglass_empty;
      } else if (isFailed) {
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.error;
      } else {
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.info;
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isSuccess
              ? theme.colorScheme.primaryContainer
              : isFailed
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSuccess
                ? theme.colorScheme.outlineVariant
                : isFailed
                    ? theme.colorScheme.error.withValues(alpha: 0.3)
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon,
                  size: 16.0,
                  color: statusColor,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Deployment ${content.environment ?? ''}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    content.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (content.message != null && content.message!.isNotEmpty) ...[
              const SizedBox(height: 4.0),
              Text(
                content.message!,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontSize: 13.0,
                ),
              ),
            ],
            if (content.url != null && content.url!.isNotEmpty) ...[
              const SizedBox(height: 4.0),
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 14.0,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4.0),
                  Expanded(
                    child: Text(
                      content.url!,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12.0,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else if (content is ErrorMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16.0,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4.0),
                Text(
                  content.code != null ? 'Error ${content.code}' : 'Error',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            ExpandableText(
              text: content.message,
              maxLines: 4,
              style: TextStyle(
                color: textColor,
                fontSize: 13.0,
              ),
            ),
            if (content.details != null) ...[
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SelectableText(
                  content.details.toString(),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 12.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is CompletionMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: content.success
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: content.success
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: content.success
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    content.message,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ],
            ),
            if (content.details != null && content.details!.isNotEmpty) ...[
              const SizedBox(height: 4.0),
              ExpandableText(
                text: content.details!,
                maxLines: 4,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is RawMessageContent) {
      // Display raw payload for debugging purposes
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.code,
                  size: 16.0,
                  color: textColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Raw Data',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SelectableText(
                content.payload.toString(),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontSize: 11.0,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
