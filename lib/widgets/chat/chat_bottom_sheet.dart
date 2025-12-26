import 'package:flutter/material.dart';
import '../../models/message.dart';
import 'message_list.dart';
import 'message_input.dart';
import 'quick_actions.dart';
import 'message_skeleton.dart';
import 'project_chat/status_dot.dart';

/// Bottom sheet chat interface for mobile devices
class ChatBottomSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingHistory;
  final bool isDeploying;
  final ScrollController? scrollController;
  final Function(String) onSendMessage;
  final Map<String, MessageStatus>? messageStatuses;
  final Function(ChatMessage)? onRetry;
  final VoidCallback? onLoadMore;
  final bool hasMoreHistory;
  final bool isLoadingMore;
  final VoidCallback? onClose;
  final VoidCallback? onRedeploy;
  final VoidCallback? onOpenFullScreen;
  final String? heroTag;
  final String? statusLabel;
  final bool statusIsError;

  const ChatBottomSheet({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isDeploying = false,
    this.scrollController,
    required this.onSendMessage,
    this.messageStatuses,
    this.onRetry,
    this.onLoadMore,
    this.hasMoreHistory = false,
    this.isLoadingMore = false,
    this.onClose,
    this.onRedeploy,
    this.onOpenFullScreen,
    this.heroTag,
    this.statusLabel,
    this.statusIsError = false,
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
    final headerDividerColor = theme.colorScheme.outline.withValues(
      alpha: 0.35,
    );

    final statusText = widget.statusLabel?.trim() ?? '';
    final showStatus = statusText.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: headerDividerColor)),
            ),
            child: Row(
              children: [
                Text(
                  'Chat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.onOpenFullScreen != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.open_in_full),
                    onPressed: widget.onOpenFullScreen,
                    iconSize: 18,
                    tooltip: 'Full screen',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                if (showStatus) ...[
                  ProjectChatStatusDot(
                    color: _statusDotColor(
                      theme,
                      statusText,
                      isError: widget.statusIsError,
                    ),
                    size: 10,
                    tooltip: statusText,
                  ),
                  const SizedBox(width: 10),
                ],
                // Redeploy button
                if (widget.onRedeploy != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.isDeploying ? null : widget.onRedeploy,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isDeploying)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isDeploying ? 'Deploying…' : 'Redeploy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Close button
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
            child: _wrapHero(
              context,
              child: widget.messages.isEmpty
                  ? widget.isLoadingHistory
                        ? _buildLoadingState()
                        : _buildEmptyState()
                  : MessageList(
                      key: const ValueKey('chat_bottom_sheet_message_list'),
                      messages: widget.messages,
                      scrollController: widget.scrollController,
                      messageStatuses: widget.messageStatuses,
                      onRetry: widget.onRetry,
                      onLoadMore: widget.onLoadMore,
                      hasMoreHistory: widget.hasMoreHistory,
                      isLoadingMore: widget.isLoadingMore,
                    ),
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

  Widget _wrapHero(BuildContext context, {required Widget child}) {
    final tag = widget.heroTag;
    if (tag == null || tag.trim().isEmpty) return child;
    final theme = Theme.of(context);
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      child: Material(
        color: theme.colorScheme.surface,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = (constraints.maxHeight * 0.48).clamp(0.0, 420.0);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH, maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy,
                  size: 44.0,
                  color: theme.colorScheme.primary.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask AI',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask about this project or paste code.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.9,
                    ),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                QuickActions(
                  onSelect: _handleSubmitted,
                  dense: true,
                  showTitle: false,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Quick actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: QuickActions(
            onSelect: _handleSubmitted,
            dense: true,
            showTitle: false,
            padding: EdgeInsets.zero,
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

Color _statusDotColor(ThemeData theme, String label, {required bool isError}) {
  final lower = label.toLowerCase().trim();
  if (isError) {
    return theme.colorScheme.error;
  }
  if (lower.contains('deploy')) {
    return theme.colorScheme.primary;
  }
  if (lower.contains('work')) {
    return Colors.amber;
  }
  if (lower.contains('think')) {
    return Colors.purple;
  }
  if (lower.contains('ready')) {
    return Colors.green;
  }
  return theme.colorScheme.onSurfaceVariant;
}
