import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expandable_text.dart';
import 'message_card_base.dart';

class ChatThinkingCard extends StatefulWidget {
  final String text;
  final bool highlight;

  const ChatThinkingCard({
    super.key,
    required this.text,
    this.highlight = false,
  });

  @override
  State<ChatThinkingCard> createState() => _ChatThinkingCardState();
}

class _ChatThinkingCardState extends State<ChatThinkingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.highlight) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ChatThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.highlight && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platinum = theme.brightness == Brightness.dark
        ? const Color(0xFFE4ECFF)
        : const Color(0xFFF9FBFF);
    final glow = theme.brightness == Brightness.dark
        ? const Color(0xFFB8C8FF)
        : const Color(0xFFD6E2FF);
    final borderColor = Color.alphaBlend(
      theme.colorScheme.primary.withValues(
        alpha: widget.highlight
            ? (theme.brightness == Brightness.dark ? 0.26 : 0.18)
            : (theme.brightness == Brightness.dark ? 0.18 : 0.12),
      ),
      theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          widget.highlight ? _controller.value : 0,
        );
        final shimmerCenter = Alignment(-1.25 + (t * 2.5), 0);
        return ChatMessageCard(
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.32,
          ),
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatCardHeader(
                icon: Icons.psychology_outlined,
                iconColor: theme.colorScheme.primary,
                title: 'Thinking',
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: widget.text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied thinking'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                copyLabel: 'Copy thinking',
              ),
              const SizedBox(height: 8),
              ExpandableText(
                text: widget.text,
                maxLines: 4,
                isMarkdown: false,
                expandText: 'Show more',
                collapseText: 'Show less',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: widget.highlight ? 0.94 : 0.85,
                  ),
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  fontSize: 13,
                  foreground: widget.highlight
                      ? (Paint()
                          ..shader = LinearGradient(
                            begin: shimmerCenter,
                            end: Alignment(shimmerCenter.x + 1.35, 0),
                            colors: [
                              theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              platinum.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.98
                                    : 0.92,
                              ),
                              glow.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.95
                                    : 0.84,
                              ),
                              theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.86,
                              ),
                            ],
                            stops: const [0.0, 0.38, 0.58, 1.0],
                          ).createShader(const Rect.fromLTWH(0, 0, 420, 48)))
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
