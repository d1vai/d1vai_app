import 'package:flutter/material.dart';
import 'markdown_text.dart';

/// Expandable markdown text widget that can show/hide long text
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final bool expandButton;
  final String expandText;
  final String collapseText;
  final bool isMarkdown;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 4,
    this.style,
    this.expandButton = true,
    this.expandText = 'Show more',
    this.collapseText = 'Show less',
    this.isMarkdown = true,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textLines = widget.text.split('\n');
    final hasMoreLines = textLines.length > widget.maxLines;
    final isLongSingleBlock = widget.text.length > 280;
    final shouldShowExpandButton =
        widget.expandButton && (hasMoreLines || isLongSingleBlock);

    String truncatedText;
    if (hasMoreLines) {
      truncatedText = textLines.take(widget.maxLines).join('\n');
    } else if (isLongSingleBlock) {
      truncatedText = '${widget.text.substring(0, 280)}…';
    } else {
      truncatedText = widget.text;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isExpanded || !shouldShowExpandButton) ...[
          widget.isMarkdown
              ? MarkdownText(text: widget.text, style: widget.style)
              : Text(widget.text, style: widget.style),
        ] else ...[
          // Show truncated text
          if (widget.isMarkdown)
            MarkdownText(text: truncatedText, style: widget.style)
          else
            Text(
              truncatedText,
              style: widget.style,
              overflow: TextOverflow.ellipsis,
            ),
        ],
        if (shouldShowExpandButton) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isExpanded ? widget.collapseText : widget.expandText,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
