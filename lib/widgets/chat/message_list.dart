// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'message_bubble.dart';
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
  bool _loadMoreRequested = false;
  double? _loadMoreStartMaxScroll;
  double? _loadMoreStartPixels;
  int? _loadMoreStartCount;

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
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _loadMoreRequested = false;
      final controller = widget.scrollController ?? _scrollController;
      final startMax = _loadMoreStartMaxScroll;
      final startPixels = _loadMoreStartPixels;
      final startCount = _loadMoreStartCount;
      _loadMoreStartMaxScroll = null;
      _loadMoreStartPixels = null;
      _loadMoreStartCount = null;

      if (startMax != null &&
          startPixels != null &&
          startCount != null &&
          widget.messages.length > startCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!controller.hasClients) return;
          final newMax = controller.position.maxScrollExtent;
          final delta = newMax - startMax;
          if (delta.abs() < 1) return;
          final target = (startPixels + delta).clamp(0.0, newMax);
          controller.jumpTo(target);
        });
      }
    }

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

  void _maybeRequestLoadMore(ScrollController controller) {
    if (widget.onLoadMore == null) return;
    if (!widget.hasMoreHistory) return;
    if (widget.isLoadingMore) return;
    if (_loadMoreRequested) return;
    if (widget.messages.isEmpty) return;
    if (!controller.hasClients) return;

    _loadMoreRequested = true;
    final maxScroll = controller.position.maxScrollExtent;
    final pixels = controller.position.pixels.clamp(0.0, maxScroll);
    _loadMoreStartMaxScroll = maxScroll;
    _loadMoreStartPixels = pixels;
    _loadMoreStartCount = widget.messages.length;
    widget.onLoadMore!();
  }

  void _onScroll() {
    final controller = widget.scrollController ?? _scrollController;
    if (!controller.hasClients) return;
    final currentScroll = controller.offset;
    // With reverse list, bottom is offset ~= 0.
    final atBottom = currentScroll <= 100;

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
  }

  void _scrollToBottom({bool animated = true}) {
    final controller = widget.scrollController ?? _scrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        if (animated) {
          controller.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          controller.jumpTo(
            0,
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
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final controller = widget.scrollController ?? _scrollController;
            if (widget.onLoadMore != null &&
                widget.hasMoreHistory &&
                !widget.isLoadingMore) {
              if (notification is OverscrollNotification) {
                // With `reverse: true`, pulling up at the very top produces
                // positive overscroll (pixels > maxScrollExtent).
                if (notification.overscroll > 0) {
                  _maybeRequestLoadMore(controller);
                }
              } else if (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) {
                final maxScroll = notification.metrics.maxScrollExtent;
                final pixels = notification.metrics.pixels;
                if (maxScroll > 0 && pixels >= maxScroll - 80) {
                  _maybeRequestLoadMore(controller);
                }
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: widget.scrollController ?? _scrollController,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16.0),
            itemCount: widget.messages.isEmpty ? 0 : (widget.messages.length + 1),
            itemBuilder: (context, index) {
              if (index == widget.messages.length) {
                return _HistoryHeader(
                  hasMore: widget.hasMoreHistory,
                  loading: widget.isLoadingMore,
                );
              }
              final message = widget.messages[widget.messages.length - 1 - index];
              final isUser = message.role == 'user';
              final isNew = !_isNewMessage(message);
              final messageStatus =
                  widget.messageStatuses?[message.id] ?? MessageStatus.sent;
              final userAccessory =
                  (isUser && messageStatus != MessageStatus.sent)
                      ? _UserSendAccessory(
                          status: messageStatus,
                          onRetry: messageStatus == MessageStatus.failed &&
                                  widget.onRetry != null
                              ? () => widget.onRetry!(message)
                              : null,
                        )
                      : null;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message bubble
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Transform.translate(
                        offset: isNew ? const Offset(0, 6) : Offset.zero,
                        child: MessageBubble(
                          message: message,
                          isUser: isUser,
                          userAccessory: userAccessory,
                          onTap: widget.onMessageTap != null
                              ? () => widget.onMessageTap!(message)
                              : null,
                        ),
                      ),
                    ),
                    if (widget.showTimestamps) ...[
                      const SizedBox(height: 1),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MessageMetadata(
                          role: message.role,
                          createdAt: message.createdAt,
                          showTimestamp: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 0),
                  ],
                ),
              );
            },
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

class _HistoryHeader extends StatelessWidget {
  final bool hasMore;
  final bool loading;

  const _HistoryHeader({required this.hasMore, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65,
    );
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.55 : 0.72,
    );

    Widget child;
    if (loading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading older messages…',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else if (hasMore) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            'Swipe up to load older',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            'Start of conversation',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _UserSendAccessory extends StatelessWidget {
  final MessageStatus status;
  final VoidCallback? onRetry;

  const _UserSendAccessory({
    required this.status,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == MessageStatus.sent) return const SizedBox.shrink();

    if (status == MessageStatus.pending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    // failed
    final bg = theme.colorScheme.error.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
    );
    final fg = theme.colorScheme.error;
    final canRetry = onRetry != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canRetry ? onRetry : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                canRetry ? 'Retry' : 'Failed',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
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
