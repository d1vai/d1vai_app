import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';

/// Message context menu actions
enum MessageAction { copy, reply, forward, delete }

/// Callback for message actions
typedef MessageActionCallback = void Function(MessageAction action);

/// Message context menu popup
class MessageContextMenu extends StatelessWidget {
  final ChatMessage message;
  final Offset? position;
  final MessageActionCallback? onActionSelected;
  final bool showDelete;

  const MessageContextMenu({
    super.key,
    required this.message,
    this.position,
    this.onActionSelected,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<MessageAction>(
      position: PopupMenuPosition.under,
      offset: position ?? Offset.zero,
      icon: Icon(
        Icons.more_vert,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      itemBuilder: (context) => [
        // Copy action
        PopupMenuItem<MessageAction>(
          value: MessageAction.copy,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(
                'Copy',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Reply action
        PopupMenuItem<MessageAction>(
          value: MessageAction.reply,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(
                'Reply',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Forward action
        PopupMenuItem<MessageAction>(
          value: MessageAction.forward,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forward, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(
                'Forward',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Delete action (if enabled)
        if (showDelete)
          PopupMenuItem<MessageAction>(
            value: MessageAction.delete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
      onSelected: (action) {
        _handleAction(context, action);
      },
    );
  }

  void _handleAction(BuildContext context, MessageAction action) {
    switch (action) {
      case MessageAction.copy:
        _copyToClipboard(context);
        break;
      case MessageAction.reply:
        onActionSelected?.call(action);
        break;
      case MessageAction.forward:
        onActionSelected?.call(action);
        break;
      case MessageAction.delete:
        onActionSelected?.call(action);
        break;
    }
  }

  void _copyToClipboard(BuildContext context) {
    // Extract text from message contents
    String text = '';
    for (var content in message.contents) {
      if (content is TextMessageContent) {
        text += content.text;
      } else if (content is ThinkingMessageContent) {
        text += content.text;
      } else if (content is CodeMessageContent) {
        text += content.code;
      } else if (content is ErrorMessageContent) {
        text += content.message;
      } else if (content is CompletionMessageContent) {
        text += content.message;
      } else {
        text += content.toString();
      }
    }

    Clipboard.setData(ClipboardData(text: text));

    // Show feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
