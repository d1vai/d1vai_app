import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/outbox.dart';

class OutboxBubbles extends StatefulWidget {
  final Color color;
  final double dotSize;

  const OutboxBubbles({
    super.key,
    required this.color,
    this.dotSize = 4,
  });

  @override
  State<OutboxBubbles> createState() => _OutboxBubblesState();
}

class _OutboxBubblesState extends State<OutboxBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.dotSize;
    final c = widget.color;

    Widget dot(double phase) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = (_controller.value + phase) % 1.0;
          final dy = -8.0 * t;
          final opacity = (t < 0.35)
              ? 0.25 + 0.65 * (t / 0.35)
              : (t < 0.70)
              ? 0.9 - 0.25 * ((t - 0.35) / 0.35)
              : 0.65 * (1.0 - ((t - 0.70) / 0.30));
          final scale = 1.0 + 0.05 * math.sin(t * math.pi);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ),
            ),
          );
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(0.0),
        const SizedBox(width: 2),
        dot(0.18),
        const SizedBox(width: 2),
        dot(0.36),
      ],
    );
  }
}

class OutboxSendPulse extends StatefulWidget {
  final Widget child;

  const OutboxSendPulse({super.key, required this.child});

  @override
  State<OutboxSendPulse> createState() => _OutboxSendPulseState();
}

class _OutboxSendPulseState extends State<OutboxSendPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dy = -1.0 * t;
        final opacity = 0.92 + 0.08 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: widget.child,
    );
  }
}

class OutboxCountBadge extends StatefulWidget {
  final int count;
  final double size;
  final EdgeInsets padding;

  const OutboxCountBadge({
    super.key,
    required this.count,
    this.size = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  State<OutboxCountBadge> createState() => _OutboxCountBadgeState();
}

class _OutboxCountBadgeState extends State<OutboxCountBadge>
    with SingleTickerProviderStateMixin {
  int _prev = 0;
  int _display = 0;
  bool _visible = false;
  bool _vanishing = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _prev = widget.count;
    _display = widget.count;
    _visible = widget.count > 0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _controller.addStatusListener((st) {
      if (st != AnimationStatus.completed) return;
      if (!mounted) return;
      if (widget.count <= 0 && _vanishing) {
        setState(() {
          _visible = false;
          _vanishing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerBurst({required bool vanishing}) {
    _vanishing = vanishing;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant OutboxCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = widget.count;
    final prev = _prev;
    _prev = c;

    if (c > 0) {
      _display = c;
      _visible = true;
      if (c < prev) _triggerBurst(vanishing: false);
      setState(() {});
      return;
    }

    if (c <= 0 && prev > 0) {
      _display = prev;
      _visible = true;
      _triggerBurst(vanishing: true);
      setState(() {});
    } else if (c == 0) {
      _visible = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;
    final fg = theme.colorScheme.onSurface.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        final popScale = 1.0 + (_vanishing ? 0.06 : 0.12) * (1.0 - (t - 0.35).clamp(0.0, 0.65) / 0.65);
        final vanishScale = _vanishing ? (1.0 - 0.30 * t) : 1.0;
        final vanishOpacity = _vanishing ? (1.0 - t) : 1.0;

        final circles = <Offset>[
          const Offset(-10, -10),
          const Offset(12, -8),
          const Offset(-12, 10),
          const Offset(10, 12),
        ];

        return Opacity(
          opacity: vanishOpacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: popScale * vanishScale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_display',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: fg,
                    ),
                  ),
                ),
                if (_controller.value > 0 && _controller.value < 1)
                  ...circles.map((o) {
                    final dx = o.dx * t;
                    final dy = o.dy * t;
                    return Positioned(
                      left: (widget.size / 2) + dx,
                      top: (widget.size / 2) + dy,
                      child: Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: fg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OutboxBar extends StatelessWidget {
  final int count;
  final OutboxMode mode;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onOpen;

  const OutboxBar({
    super.key,
    required this.count,
    required this.mode,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.65,
    );
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final fg = theme.colorScheme.onSurface.withValues(alpha: 0.85);

    Color dotColor;
    if (mode == OutboxMode.pausedError) {
      dotColor = theme.colorScheme.error;
    } else if (mode == OutboxMode.dispatching) {
      dotColor = theme.colorScheme.primary;
    } else if (mode == OutboxMode.waitingTask || mode == OutboxMode.waitingWorkspace) {
      dotColor = theme.colorScheme.tertiary;
    } else {
      dotColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    }

    Widget rightGlyph() {
      if (mode == OutboxMode.dispatching) {
        return OutboxSendPulse(
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        );
      }
      if (mode == OutboxMode.waitingWorkspace || mode == OutboxMode.waitingTask) {
        return OutboxBubbles(color: theme.colorScheme.onSurfaceVariant);
      }
      if (mode == OutboxMode.pausedError) {
        return Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error);
      }
      return const SizedBox(width: 18, height: 18);
    }

    final body = Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          '⏎',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        const SizedBox(width: 6),
        OutboxCountBadge(count: count, size: 18),
        const Spacer(),
        rightGlyph(),
        const SizedBox(width: 10),
        InkWell(
          onTap: onToggleCollapsed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: collapsed
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: collapsed ? SizedBox(height: 20, child: body) : body,
        ),
      ),
    );
  }
}

Future<void> showOutboxSheet(
  BuildContext context, {
  required List<OutboxItem> items,
  required OutboxMode mode,
  required VoidCallback onClear,
  required void Function(OutboxItem item) onDelete,
  required void Function(OutboxItem item, String nextPrompt) onUpdate,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _OutboxSheet(
        items: items,
        mode: mode,
        onClear: onClear,
        onDelete: onDelete,
        onUpdate: onUpdate,
      );
    },
  );
}

class _OutboxSheet extends StatefulWidget {
  final List<OutboxItem> items;
  final OutboxMode mode;
  final VoidCallback onClear;
  final void Function(OutboxItem item) onDelete;
  final void Function(OutboxItem item, String nextPrompt) onUpdate;

  const _OutboxSheet({
    required this.items,
    required this.mode,
    required this.onClear,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_OutboxSheet> createState() => _OutboxSheetState();
}

class _OutboxSheetState extends State<_OutboxSheet> {
  String? _editingId;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEdit(OutboxItem item) {
    setState(() {
      _editingId = item.id;
      _controller.text = item.prompt;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _controller.clear();
    });
    try {
      _focusNode.unfocus();
    } catch (_) {}
  }

  void _saveEdit(OutboxItem item) {
    final next = _controller.text.trim();
    widget.onUpdate(item, next);
    _cancelEdit();
  }

  String _hint() {
    final mode = widget.mode;
    if (mode == OutboxMode.waitingWorkspace) return 'Waiting for workspace…';
    if (mode == OutboxMode.waitingTask) return 'Waiting for previous task…';
    if (mode == OutboxMode.dispatching) return 'Sending…';
    if (mode == OutboxMode.pausedError) return 'Paused (an item failed).';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgMuted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final items = widget.items;
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'Outbox',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        widget.onClear();
                        if (!mounted) return;
                        setState(() {
                          _editingId = null;
                          _controller.clear();
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              if (_hint().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _hint(),
                      style: theme.textTheme.bodySmall?.copyWith(color: fgMuted),
                    ),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'No queued messages.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: fgMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final isRunning = item.status == OutboxItemStatus.running;
                          final canEdit = !isRunning;
                          final isEditing = _editingId == item.id;

                          Widget trailingIcons() {
                            final iconFg = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
                            final iconBg = theme.colorScheme.surfaceContainerHighest.withValues(
                              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.85,
                            );

                            Widget iconBtn({
                              required IconData icon,
                              required String tooltip,
                              required VoidCallback? onTap,
                              Color? color,
                            }) {
                              return Tooltip(
                                message: tooltip,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onTap,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 18,
                                        color: color ?? iconFg,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (isRunning) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: OutboxBubbles(
                                  color: theme.colorScheme.primary,
                                  dotSize: 4.5,
                                ),
                              );
                            }

                            if (isEditing) {
                              final canSave = _controller.text.trim().isNotEmpty;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  iconBtn(
                                    icon: Icons.close,
                                    tooltip: 'Cancel',
                                    onTap: _cancelEdit,
                                  ),
                                  const SizedBox(width: 8),
                                  iconBtn(
                                    icon: Icons.check,
                                    tooltip: 'Save',
                                    onTap: canSave ? () => _saveEdit(item) : null,
                                    color: canSave
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                iconBtn(
                                  icon: Icons.edit,
                                  tooltip: 'Edit',
                                  onTap: canEdit ? () => _startEdit(item) : null,
                                ),
                                const SizedBox(width: 8),
                                iconBtn(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Delete',
                                  onTap: canEdit
                                      ? () {
                                          widget.onDelete(item);
                                          if (!mounted) return;
                                          if (_editingId == item.id) {
                                            _cancelEdit();
                                          }
                                          setState(() {});
                                        }
                                      : null,
                                  color: theme.colorScheme.error.withValues(alpha: 0.9),
                                ),
                              ],
                            );
                          }

                          Widget content() {
                            if (!isEditing) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.prompt,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.error != null && item.error!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.error!.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }

                            return TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Edit message…',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) {
                                if (_controller.text.trim().isEmpty) return;
                                _saveEdit(item);
                              },
                            );
                          }

                          final canDismiss = !isRunning && !isEditing;
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: canDismiss
                                ? DismissDirection.horizontal
                                : DismissDirection.none,
                            confirmDismiss: (direction) async {
                              if (!canDismiss) return false;
                              if (direction == DismissDirection.startToEnd) {
                                _startEdit(item);
                                return false;
                              }
                              if (direction == DismissDirection.endToStart) {
                                widget.onDelete(item);
                                if (mounted) setState(() {});
                                return true;
                              }
                              return false;
                            },
                            background: Container(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Edit',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              color: theme.colorScheme.error.withValues(alpha: 0.12),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Delete',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.delete, color: theme.colorScheme.error),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Card(
                                elevation: 0,
                                color: theme.colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onLongPress: isRunning
                                      ? null
                                      : () async {
                                          await showModalBottomSheet<void>(
                                            context: context,
                                            useSafeArea: true,
                                            backgroundColor: theme.colorScheme.surface,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(18),
                                              ),
                                            ),
                                            builder: (context) {
                                              return SafeArea(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(Icons.edit),
                                                      title: const Text('Edit'),
                                                      enabled: canEdit,
                                                      onTap: !canEdit
                                                          ? null
                                                          : () {
                                                              Navigator.pop(context);
                                                              _startEdit(item);
                                                            },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(Icons.delete),
                                                      title: const Text('Delete'),
                                                      enabled: canEdit,
                                                      onTap: !canEdit
                                                          ? null
                                                          : () {
                                                              widget.onDelete(item);
                                                              Navigator.pop(context);
                                                              if (mounted) setState(() {});
                                                            },
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ListTile(
                                                      leading: const Icon(Icons.close),
                                                      title: const Text('Cancel'),
                                                      onTap: () => Navigator.pop(context),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: content()),
                                        const SizedBox(width: 10),
                                        trailingIcons(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }
}
