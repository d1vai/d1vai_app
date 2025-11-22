import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';

/// Message bubble widget for displaying chat messages
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
                  children: message.contents.map((content) {
                    return _buildMessageContent(content, isUser, context);
                  }).toList(),
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
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    if (content is TextMessageContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Text(
          content.text,
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
                  Icons.build,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Tool: ${content.name}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            if (content.input != null) ...[
              const SizedBox(height: 4.0),
              Text(
                content.input.toString(),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 13.0,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      );
    } else if (content is GitCommitMessageContent) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.commit,
                  size: 16.0,
                  color: Colors.green,
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
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: content.success
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.3),
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
                  color: content.success ? Colors.green : Colors.red,
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
                  color: Colors.red,
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
