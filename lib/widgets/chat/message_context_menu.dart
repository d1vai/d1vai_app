import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../app_menu_button.dart';
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
    if (_isMobilePlatform) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AppMenuButton<MessageAction>(
      position: PopupMenuPosition.under,
      offset: position ?? Offset.zero,
      padding: const EdgeInsets.all(4),
      borderRadius: 10,
      icon: Icon(
        Icons.more_vert,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      actions: [
        const AppMenuAction(
          value: MessageAction.copy,
          label: 'Copy',
          icon: Icons.copy,
        ),
        const AppMenuAction(
          value: MessageAction.reply,
          label: 'Reply',
          icon: Icons.reply,
        ),
        const AppMenuAction(
          value: MessageAction.forward,
          label: 'Forward',
          icon: Icons.forward,
        ),
        if (showDelete)
          const AppMenuAction(
            value: MessageAction.delete,
            label: 'Delete',
            icon: Icons.delete_outline,
            destructive: true,
          ),
      ],
      onSelected: (action) {
        _handleAction(context, action);
      },
    );
  }

  static bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  static Future<void> showMobileActionSheet(
    BuildContext context, {
    required ChatMessage message,
    MessageActionCallback? onActionSelected,
    bool showDelete = false,
  }) async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Widget tile({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color? color,
        }) {
          final resolved = color ?? theme.colorScheme.onSurface;
          return ListTile(
            leading: Icon(icon, color: resolved),
            title: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: resolved,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: onTap,
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                tile(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () {
                    Navigator.of(context).pop();
                    _copyMessageToClipboard(context, message);
                  },
                ),
                tile(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.of(context).pop();
                    onActionSelected?.call(MessageAction.reply);
                  },
                ),
                tile(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  onTap: () {
                    Navigator.of(context).pop();
                    onActionSelected?.call(MessageAction.forward);
                  },
                ),
                if (showDelete)
                  tile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: theme.colorScheme.error,
                    onTap: () {
                      Navigator.of(context).pop();
                      onActionSelected?.call(MessageAction.delete);
                    },
                  ),
              ],
            ),
          ),
        );
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
    _copyMessageToClipboard(context, message);
  }

  static void _copyMessageToClipboard(
    BuildContext context,
    ChatMessage message,
  ) {
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
