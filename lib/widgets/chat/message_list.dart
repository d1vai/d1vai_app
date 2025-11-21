import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';

/// Scrollable list of chat messages
class MessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isTyping;
  final Function(ChatMessage)? onMessageTap;
  final ScrollController? scrollController;

  const MessageList({
    super.key,
    required this.messages,
    this.isTyping = false,
    this.onMessageTap,
    this.scrollController,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    final controller = widget.scrollController ?? _scrollController;
    controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController ?? _scrollController;
    final maxScroll = controller.position.maxScrollExtent;
    final currentScroll = controller.offset;
    final atBottom = currentScroll >= maxScroll - 100;

    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    final controller = widget.scrollController ?? _scrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        if (animated) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          controller.jumpTo(
            controller.position.maxScrollExtent,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController ?? _scrollController,
          padding: const EdgeInsets.only(bottom: 16.0),
          itemCount: widget.messages.length + (widget.isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == widget.messages.length) {
              return const TypingIndicator();
            }

            final message = widget.messages[index];
            final isUser = message.role == 'user';

            return MessageBubble(
              message: message,
              isUser: isUser,
              onTap: widget.onMessageTap != null
                  ? () => widget.onMessageTap!(message)
                  : null,
            );
          },
        ),
        // Scroll to bottom button
        if (!_isAtBottom && widget.messages.isNotEmpty)
          Positioned(
            bottom: 80.0,
            right: 16.0,
            child: FloatingActionButton.small(
              onPressed: () => _scrollToBottom(),
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }
}

/// Empty state widget for no messages
class EmptyMessageList extends StatelessWidget {
  final String? title;
  final String? message;

  const EmptyMessageList({
    super.key,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64.0,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16.0),
            Text(
              title ?? 'No messages yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              message ?? 'Start a conversation with AI',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
