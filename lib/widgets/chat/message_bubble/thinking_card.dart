import 'package:flutter/material.dart';

import '../expandable_text.dart';

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
        ? const Color(0xFFEAF1FF)
        : const Color(0xFFF7FBFF);
    final glow = theme.brightness == Brightness.dark
        ? const Color(0xFFBDD0FF)
        : const Color(0xFFD9E8FF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          widget.highlight ? _controller.value : 0,
        );
        final shimmerCenter = Alignment(-1.25 + (t * 2.5), 0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpandableText(
                text: '💭 ${widget.text}',
                maxLines: 4,
                isMarkdown: false,
                expandText: 'Show more',
                collapseText: 'Show less',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  fontSize: 13,
                  color: widget.highlight
                      ? null
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.88,
                        ),
                  foreground: widget.highlight
                      ? (Paint()
                          ..shader = LinearGradient(
                            begin: shimmerCenter,
                            end: Alignment(shimmerCenter.x + 1.35, 0),
                            colors: [
                              theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              platinum.withValues(alpha: 0.96),
                              glow.withValues(alpha: 0.88),
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
