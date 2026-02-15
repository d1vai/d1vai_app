import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final String expandText;
  final String collapseText;
  final TextStyle? textStyle;
  final TextStyle? linkStyle;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final Widget? expandIcon;
  final Widget? collapseIcon;
  final bool showIcon;
  final Duration? animationDuration;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment? crossAxisAlignment;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 3,
    this.expandText = 'Show more',
    this.collapseText = 'Show less',
    this.textStyle,
    this.linkStyle,
    this.expanded = false,
    this.onExpandedChanged,
    this.expandIcon,
    this.collapseIcon,
    this.showIcon = true,
    this.animationDuration,
    this.padding,
    this.crossAxisAlignment,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText>
    with TickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expanded;
  }

  @override
  void didUpdateWidget(ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _isExpanded = widget.expanded;
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandedChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle =
        widget.textStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);

    final effectiveLinkStyle =
        widget.linkStyle ??
        effectiveTextStyle.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment ?? CrossAxisAlignment.start,
      children: [
        widget.padding != null
            ? Padding(
                padding: widget.padding!,
                child: _buildText(effectiveTextStyle, effectiveLinkStyle),
              )
            : _buildText(effectiveTextStyle, effectiveLinkStyle),
        if (_shouldShowToggle()) _buildToggle(effectiveLinkStyle),
      ],
    );
  }

  Widget _buildText(TextStyle textStyle, TextStyle linkStyle) {
    if (_isExpanded) {
      return Text(widget.text, style: textStyle);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
        );

        final isTextOverflowing = textPainter.didExceedMaxLines;

        if (!isTextOverflowing) {
          return Text(widget.text, style: textStyle);
        }

        return Text(
          widget.text,
          style: textStyle,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildToggle(TextStyle linkStyle) {
    return GestureDetector(
      onTap: _toggleExpansion,
      child: AnimatedContainer(
        duration: widget.animationDuration ?? const Duration(milliseconds: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration:
                    widget.animationDuration ??
                    const Duration(milliseconds: 200),
                child:
                    widget.expandIcon ??
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: linkStyle.color,
                    ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _isExpanded ? widget.collapseText : widget.expandText,
              style: linkStyle,
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowToggle() {
    // Always show toggle - the text will naturally handle showing it only when needed
    return true;
  }
}

/// ExpandableText with custom widget support
class ExpandableWidget extends StatefulWidget {
  final Widget child;
  final int maxLines;
  final String expandText;
  final String collapseText;
  final TextStyle? textStyle;
  final TextStyle? linkStyle;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final Widget? expandIcon;
  final Widget? collapseIcon;
  final bool showIcon;
  final Duration? animationDuration;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment? crossAxisAlignment;

  const ExpandableWidget({
    super.key,
    required this.child,
    this.maxLines = 3,
    this.expandText = 'Show more',
    this.collapseText = 'Show less',
    this.textStyle,
    this.linkStyle,
    this.expanded = false,
    this.onExpandedChanged,
    this.expandIcon,
    this.collapseIcon,
    this.showIcon = true,
    this.animationDuration,
    this.padding,
    this.crossAxisAlignment,
  });

  @override
  State<ExpandableWidget> createState() => _ExpandableWidgetState();
}

class _ExpandableWidgetState extends State<ExpandableWidget>
    with TickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expanded;
  }

  @override
  void didUpdateWidget(ExpandableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _isExpanded = widget.expanded;
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandedChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle =
        widget.textStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);

    final effectiveLinkStyle =
        widget.linkStyle ??
        effectiveTextStyle.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment ?? CrossAxisAlignment.start,
      children: [
        widget.padding != null
            ? Padding(
                padding: widget.padding!,
                child: AnimatedCrossFade(
                  firstChild: widget.child,
                  secondChild: widget.child,
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration:
                      widget.animationDuration ??
                      const Duration(milliseconds: 200),
                ),
              )
            : AnimatedCrossFade(
                firstChild: widget.child,
                secondChild: widget.child,
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration:
                    widget.animationDuration ??
                    const Duration(milliseconds: 200),
              ),
        if (_shouldShowToggle()) _buildToggle(effectiveLinkStyle),
      ],
    );
  }

  Widget _buildToggle(TextStyle linkStyle) {
    return GestureDetector(
      onTap: _toggleExpansion,
      child: AnimatedContainer(
        duration: widget.animationDuration ?? const Duration(milliseconds: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration:
                    widget.animationDuration ??
                    const Duration(milliseconds: 200),
                child:
                    widget.expandIcon ??
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: linkStyle.color,
                    ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _isExpanded ? widget.collapseText : widget.expandText,
              style: linkStyle,
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowToggle() {
    return true;
  }
}
