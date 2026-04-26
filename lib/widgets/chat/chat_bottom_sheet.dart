import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../models/model_config.dart';
import '../../models/outbox.dart';
import 'message_list.dart';
import 'message_input.dart';
import 'quick_actions.dart';
import 'message_skeleton.dart';
import 'project_chat/chat_engine_mode.dart';
import 'project_chat/project_chat_top_bar.dart';
import 'status_pill.dart';
import 'outbox/outbox_widgets.dart';

/// Bottom sheet chat interface for mobile devices
class ChatBottomSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingHistory;
  final bool isDeploying;
  final ScrollController? scrollController;
  final Function(String) onSendMessage;
  final List<OutboxItem> outboxItems;
  final OutboxMode outboxMode;
  final VoidCallback? onOutboxClear;
  final void Function(OutboxItem item)? onOutboxDelete;
  final void Function(OutboxItem item, String nextPrompt)? onOutboxUpdate;
  final Map<String, MessageStatus>? messageStatuses;
  final Function(ChatMessage)? onRetry;
  final VoidCallback? onLoadMore;
  final bool hasMoreHistory;
  final bool isLoadingMore;
  final VoidCallback? onClose;
  final VoidCallback? onOpenFullScreen;
  final String? heroTag;
  final String? statusLabel;
  final bool statusIsError;
  final bool isModelReady;
  final bool isModelLoading;
  final List<ModelInfo> models;
  final String selectedModelId;
  final ChatEngineMode selectedEngineMode;
  final ValueChanged<String>? onModelChanged;
  final ValueChanged<ChatEngineMode>? onEngineChanged;
  final TextEditingController? inputController;
  final FocusNode? inputFocusNode;
  final ValueChanged<String>? onInputChanged;
  final List<QuickActionItem> quickActions;
  final String? quickActionsTitle;
  final String? bannerTitle;
  final String? bannerMessage;
  final IconData bannerIcon;
  final Color? bannerAccent;
  final bool bannerBusy;

  const ChatBottomSheet({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isDeploying = false,
    this.scrollController,
    required this.onSendMessage,
    this.outboxItems = const <OutboxItem>[],
    this.outboxMode = OutboxMode.idle,
    this.onOutboxClear,
    this.onOutboxDelete,
    this.onOutboxUpdate,
    this.messageStatuses,
    this.onRetry,
    this.onLoadMore,
    this.hasMoreHistory = false,
    this.isLoadingMore = false,
    this.onClose,
    this.onOpenFullScreen,
    this.heroTag,
    this.statusLabel,
    this.statusIsError = false,
    this.isModelReady = true,
    this.isModelLoading = false,
    this.models = const <ModelInfo>[],
    this.selectedModelId = '',
    this.selectedEngineMode = ChatEngineMode.thinkHard,
    this.onModelChanged,
    this.onEngineChanged,
    this.inputController,
    this.inputFocusNode,
    this.onInputChanged,
    this.quickActions = const <QuickActionItem>[],
    this.quickActionsTitle,
    this.bannerTitle,
    this.bannerMessage,
    this.bannerIcon = Icons.info_outline_rounded,
    this.bannerAccent,
    this.bannerBusy = false,
  });

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  bool _outboxCollapsed = false;

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    widget.onSendMessage(text);
  }

  void _openOutbox() {
    final items = widget.outboxItems;
    if (items.isEmpty) return;
    showOutboxSheet(
      context,
      items: items,
      mode: widget.outboxMode,
      onClear: widget.onOutboxClear ?? () {},
      onDelete: widget.onOutboxDelete ?? (_) {},
      onUpdate: widget.onOutboxUpdate ?? (item, nextPrompt) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerDividerColor = theme.colorScheme.outline.withValues(
      alpha: 0.35,
    );

    final statusText = widget.statusLabel?.trim() ?? '';
    final showStatus = statusText.isNotEmpty;
    final fastHint = 'Fast mode uses Claude engine';
    final thinkHardHint = 'Think Hard mode uses Codex engine';
    final bannerTitle = widget.bannerTitle?.trim() ?? '';
    final bannerMessage = widget.bannerMessage?.trim() ?? '';
    final showBanner = bannerTitle.isNotEmpty || bannerMessage.isNotEmpty;

    return Container(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final modelWidth = math.min(128.0, constraints.maxWidth * 0.28);

                return Row(
                  children: [
                    Text(
                      'Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.onOpenFullScreen != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.open_in_full),
                        onPressed: widget.onOpenFullScreen,
                        iconSize: 18,
                        tooltip: 'Full screen',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ProjectChatModelSelector(
                          models: widget.models,
                          selectedModelId: widget.selectedModelId,
                          isLoading: widget.isModelLoading,
                          onChanged: widget.onModelChanged,
                          minWidth: 92,
                          maxWidth: modelWidth,
                          width: modelWidth,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProjectChatEngineModeSegment(
                      value: widget.selectedEngineMode,
                      fastTooltip: fastHint,
                      thinkHardTooltip: thinkHardHint,
                      onChanged: widget.isModelLoading
                          ? null
                          : widget.onEngineChanged,
                    ),
                    if (showStatus) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SizeTransition(
                                sizeFactor: anim,
                                axis: Axis.horizontal,
                                axisAlignment: -1,
                                child: child,
                              ),
                            ),
                            child: ChatStatusPill(
                              key: ValueKey(statusText),
                              label: statusText,
                              isError: widget.statusIsError,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      iconSize: 20,
                      tooltip: 'Close',
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: !showBanner
                ? const SizedBox.shrink()
                : _ChatStatusBanner(
                    key: ValueKey('$bannerTitle|$bannerMessage'),
                    title: bannerTitle,
                    message: bannerMessage,
                    icon: widget.bannerIcon,
                    accent: widget.bannerAccent ?? theme.colorScheme.primary,
                    busy: widget.bannerBusy,
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

          // Outbox bar (queue)
          OutboxBar(
            count: widget.outboxItems.length,
            mode: widget.outboxMode,
            collapsed: _outboxCollapsed,
            onToggleCollapsed: () {
              setState(() {
                _outboxCollapsed = !_outboxCollapsed;
              });
            },
            onOpen: _openOutbox,
          ),

          // Input field
          MessageInput(
            onSend: _handleSubmitted,
            isEnabled:
                !widget.isLoading &&
                widget.isModelReady &&
                !widget.isModelLoading,
            hintText: widget.isModelLoading
                ? 'Model is loading…'
                : (widget.isModelReady
                      ? 'Ask about this project…'
                      : 'Model not ready'),
            controller: widget.inputController,
            focusNode: widget.inputFocusNode,
            onChanged: widget.onInputChanged,
            queueCount: widget.outboxItems.length,
            showSendPulse: widget.outboxMode == OutboxMode.dispatching,
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
                  'Ask',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask about the project or paste code.',
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
                  actions: widget.quickActions.isEmpty
                      ? null
                      : widget.quickActions,
                  title: widget.quickActionsTitle,
                  dense: true,
                  showTitle: false,
                  animateIn: false,
                  enableBreathing: false,
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
            actions: widget.quickActions.isEmpty ? null : widget.quickActions,
            title: widget.quickActionsTitle,
            dense: true,
            showTitle: false,
            animateIn: false,
            enableBreathing: false,
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

class _ChatStatusBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final bool busy;

  const _ChatStatusBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.10 : 0.08),
      theme.colorScheme.surface,
    );
    final border = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.24 : 0.18),
      theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.3,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
