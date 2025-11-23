import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'message_list.dart';
import 'message_input.dart';
import 'quick_actions.dart';
import 'message_skeleton.dart';

/// Bottom sheet chat interface for mobile devices
class ChatBottomSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isTyping;
  final bool isLoading;
  final bool isLoadingHistory;
  final ScrollController? scrollController;
  final Function(String) onSendMessage;
  final VoidCallback? onClose;

  const ChatBottomSheet({
    super.key,
    required this.messages,
    this.isTyping = false,
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.scrollController,
    required this.onSendMessage,
    this.onClose,
  });

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  @override
  void dispose() {
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Chat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  iconSize: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: widget.messages.isEmpty && !widget.isTyping
                ? widget.isLoadingHistory
                    ? _buildLoadingState()
                    : _buildEmptyState()
                : Column(
                    children: [
                      // Quick actions when no messages
                      if (widget.messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: QuickActions(
                            onSelect: _handleSubmitted,
                          ),
                        ),
                      // Messages
                      Expanded(
                        child: MessageList(
                          messages: widget.messages,
                          isTyping: widget.isTyping,
                          scrollController: widget.scrollController,
                        ),
                      ),
                    ],
                  ),
          ),

          // Input field
          MessageInput(
            onSend: _handleSubmitted,
            isEnabled: !widget.isLoading,
            hintText: 'Ask about your project...',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy,
              size: 80.0,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Chat with AI',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12.0),
            Text(
              'Ask me anything about your project,\ncode, or get help with development',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Quick actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: QuickActions(
            onSelect: _handleSubmitted,
          ),
        ),
        // Loading skeleton
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  MessageSkeleton(isUser: true, delay: 0),
                  MessageSkeleton(isUser: false, delay: 150),
                  MessageSkeleton(isUser: true, delay: 300),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
