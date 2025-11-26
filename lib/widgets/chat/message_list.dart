// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'message_metadata.dart';

/// Message status enum
enum MessageStatus {
  pending,
  sent,
  failed,
}

/// Enhanced scrollable list of chat messages with advanced features
class MessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isTyping;
  final Function(ChatMessage)? onMessageTap;
  final ScrollController? scrollController;
  final Map<String, MessageStatus>? messageStatuses;
  final Function(ChatMessage)? onRetry;
  final VoidCallback? onLoadMore;
  final bool hasMoreHistory;
  final bool isLoadingMore;
  final bool showTimestamps;

  const MessageList({
    super.key,
    required this.messages,
    this.isTyping = false,
    this.onMessageTap,
    this.scrollController,
    this.messageStatuses,
    this.onRetry,
    this.onLoadMore,
    this.hasMoreHistory = false,
    this.isLoadingMore = false,
    this.showTimestamps = false,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _seenMessages = {};
  String? _lastSeenMessageId;
  bool _isAtBottom = true;
  int _unseenCount = 0;

  @override
  void initState() {
    super.initState();
    final controller = widget.scrollController ?? _scrollController;
    controller.addListener(_onScroll);

    // Initialize seen messages
    for (final message in widget.messages) {
      _seenMessages.add(message.id);
    }
    _lastSeenMessageId = widget.messages.isNotEmpty
        ? widget.messages.last.id
        : null;

    // Initial scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update seen messages when new messages arrive
    if (widget.messages.length > oldWidget.messages.length) {
      // Mark new messages as unseen
      for (int i = oldWidget.messages.length;
          i < widget.messages.length;
          i++) {
        final newMessage = widget.messages[i];
        _seenMessages.add(newMessage.id);
      }

      // Update last seen message if at bottom
      if (_isAtBottom && widget.messages.isNotEmpty) {
        _lastSeenMessageId = widget.messages.last.id;
        _unseenCount = 0;
      }
    }
  }

  @override
  void dispose() {
    final controller = widget.scrollController ?? _scrollController;
    controller.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
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

      // Update last seen message when scrolling to bottom
      if (atBottom && widget.messages.isNotEmpty) {
        _lastSeenMessageId = widget.messages.last.id;
        _unseenCount = 0;
      }
    }

    // Load more history when near top
    if (widget.onLoadMore != null &&
        widget.hasMoreHistory &&
        !widget.isLoadingMore &&
        currentScroll <= 50 &&
        widget.messages.isNotEmpty) {
      widget.onLoadMore!();
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

  bool _isNewMessage(ChatMessage message) {
    return _seenMessages.contains(message.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController ?? _scrollController,
          padding: const EdgeInsets.only(bottom: 16.0),
          itemCount: widget.messages.length + (widget.isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            // Typing indicator at the end
            if (index == widget.messages.length) {
              return widget.isTyping
                  ? const TypingIndicator(isTyping: true)
                  : const SizedBox.shrink();
            }

            final message = widget.messages[index];
            final isUser = message.role == 'user';
            final isNew = !_isNewMessage(message);
            final messageStatus =
                widget.messageStatuses?[message.id] ?? MessageStatus.sent;

            return AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message metadata
                  Padding(
                    padding:
                        EdgeInsets.only(left: isUser ? 0 : 56, right: isUser ? 56 : 0),
                    child: MessageMetadata(
                      role: message.role,
                      createdAt: message.createdAt,
                      status: messageStatus == MessageStatus.pending
                          ? 'pending'
                          : messageStatus == MessageStatus.failed
                              ? 'failed'
                              : null,
                      onRetry:
                          messageStatus == MessageStatus.failed && widget.onRetry != null
                              ? () => widget.onRetry!(message)
                              : null,
                      showTimestamp: widget.showTimestamps,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Message bubble
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: Duration(milliseconds: 300),
                    child: Transform.translate(
                      offset: isNew
                          ? Offset(
                              isUser ? 50 : -50,
                              0,
                            )
                          : Offset.zero,
                      child: MessageBubble(
                        message: message,
                        isUser: isUser,
                        onTap: widget.onMessageTap != null
                            ? () => widget.onMessageTap!(message)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        ),

        // Load more indicator
        if (widget.isLoadingMore)
          Positioned(
            key: const ValueKey('load_more_indicator'),
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading more...',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Beginning of conversation indicator
        // Show only if there are 3 or fewer messages
        if (!widget.hasMoreHistory &&
            widget.messages.isNotEmpty &&
            widget.messages.length <= 3)
          Positioned(
            key: const ValueKey('beginning_of_conversation'),
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🎉 Beginning of conversation',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

        // Scroll to bottom button with unseen count
        if (!_isAtBottom && widget.messages.isNotEmpty)
          Positioned(
            key: const ValueKey('scroll_to_bottom_button'),
            bottom: 80,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _scrollToBottom();
                _lastSeenMessageId = widget.messages.last.id;
                _unseenCount = 0;
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_downward,
                      color: Colors.white,
                      size: 16,
                    ),
                    if (_unseenCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$_unseenCount new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
