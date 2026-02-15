import 'package:flutter/material.dart';

import 'outbox/outbox_widgets.dart';

/// Message input field for sending chat messages
class MessageInput extends StatefulWidget {
  final Function(String) onSend;
  final bool isEnabled;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int queueCount;
  final bool showSendPulse;

  const MessageInput({
    super.key,
    required this.onSend,
    this.isEnabled = true,
    this.hintText,
    this.controller,
    this.focusNode,
    this.queueCount = 0,
    this.showSendPulse = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;
  bool _isComposing = false;
  bool _isFocused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  void _syncComposingFromController() {
    final next = _controller.text.trim().isNotEmpty;
    if (next == _isComposing) return;
    if (!mounted) return;
    setState(() {
      _isComposing = next;
    });
  }

  @override
  void dispose() {
    try {
      _controller.removeListener(_syncComposingFromController);
    } catch (_) {}
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncComposingFromController);
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    _syncComposingFromController();
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      try {
        oldWidget.controller?.removeListener(_syncComposingFromController);
      } catch (_) {}
      widget.controller?.addListener(_syncComposingFromController);
      _syncComposingFromController();
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.isEnabled;
    final canSend = enabled && _isComposing;
    final queueCount = widget.queueCount;
    final borderColor = _isFocused
        ? theme.colorScheme.primary.withValues(alpha: 0.70)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.70);
    final fieldBg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.55 : 0.85,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: enabled
                      ? fieldBg
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.25,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Ask about your project…',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (text) {
                    final next = text.trim().isNotEmpty;
                    if (next == _isComposing) return;
                    setState(() {
                      _isComposing = next;
                    });
                  },
                  onSubmitted: _handleSubmitted,
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              scale: canSend ? 1.0 : 0.96,
              child: Material(
                color: canSend
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: canSend
                      ? () => _handleSubmitted(_controller.text)
                      : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: widget.showSendPulse && canSend
                              ? OutboxSendPulse(
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: canSend
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.65),
                                ),
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: OutboxCountBadge(
                            count: queueCount,
                            size: 18,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
