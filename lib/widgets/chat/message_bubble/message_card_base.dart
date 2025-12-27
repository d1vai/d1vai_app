import 'package:flutter/material.dart';

class ChatMessageCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const ChatMessageCard({
    super.key,
    required this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: child,
    );
  }
}

class ChatCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onCopy;
  final String? copyLabel;

  const ChatCardHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onCopy,
    this.copyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(
                Icons.copy,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
                semanticLabel: copyLabel ?? 'Copy',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ChatExpandableSelectableBlock extends StatefulWidget {
  final String text;
  final int collapsedLines;
  final TextStyle? style;

  const ChatExpandableSelectableBlock({
    super.key,
    required this.text,
    required this.collapsedLines,
    this.style,
  });

  @override
  State<ChatExpandableSelectableBlock> createState() =>
      _ChatExpandableSelectableBlockState();
}

class _ChatExpandableSelectableBlockState
    extends State<ChatExpandableSelectableBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.text.split('\n').length;
    final canExpand = lines > widget.collapsedLines || widget.text.length > 280;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            widget.text,
            maxLines: _expanded ? null : widget.collapsedLines,
            style: widget.style,
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Color chatSuccessTint(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade700;
}

Color chatWarningTint(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.amber.shade300
      : Colors.amber.shade800;
}

