import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/terminal_session_controller.dart';
import '../../l10n/app_localizations.dart';

class TerminalStatusOverlay extends StatefulWidget {
  final TerminalSessionPhase phase;
  final int? exitCode;
  final bool retryable;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;

  const TerminalStatusOverlay({
    super.key,
    required this.phase,
    this.exitCode,
    this.retryable = false,
    this.onOpen,
    this.onRetry,
  });

  @override
  State<TerminalStatusOverlay> createState() => _TerminalStatusOverlayState();
}

class _TerminalStatusOverlayState extends State<TerminalStatusOverlay>
    with TickerProviderStateMixin {
  static const _minimumStartupDuration = Duration(milliseconds: 650);
  static const _openingDuration = Duration(milliseconds: 1120);
  static const _reducedOpeningDuration = Duration(milliseconds: 160);

  late final AnimationController _startupController;
  late final AnimationController _openingController;
  Timer? _readyTimer;
  bool _showBootGate = false;
  bool _reduceMotion = false;
  TerminalSessionPhase _displayPhase = TerminalSessionPhase.creating;

  @override
  void initState() {
    super.initState();
    _startupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _openingController = AnimationController(
      vsync: this,
      duration: _openingDuration,
    );
    if (_isPending(widget.phase)) _beginStartup(widget.phase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_isPending(widget.phase)) {
      if (_reduceMotion) {
        _startupController.stop();
      } else if (!_startupController.isAnimating) {
        _startupController.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant TerminalStatusOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasPending = _isPending(oldWidget.phase);
    final isPending = _isPending(widget.phase);

    if (isPending) {
      _displayPhase = widget.phase;
      if (!wasPending) _beginStartup(widget.phase);
      return;
    }

    if (wasPending && widget.phase == TerminalSessionPhase.ready) {
      _showBootGate = true;
      _scheduleOpening();
      return;
    }

    _resetMechanicalStage();
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _startupController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  void _beginStartup(TerminalSessionPhase phase) {
    _readyTimer?.cancel();
    _readyTimer = null;
    _displayPhase = phase;
    _showBootGate = false;
    _openingController.stop();
    _openingController.value = 0;
    _startupController.stop();
    _startupController.value = 0;
    if (!_reduceMotion) _startupController.repeat();
  }

  void _scheduleOpening() {
    _readyTimer?.cancel();
    if (_reduceMotion) {
      _beginOpening();
      return;
    }
    final elapsed = _startupController.lastElapsedDuration ?? Duration.zero;
    final remaining = _minimumStartupDuration - elapsed;
    if (remaining <= Duration.zero) {
      _beginOpening();
    } else {
      _readyTimer = Timer(remaining, _beginOpening);
    }
  }

  void _beginOpening() {
    if (!mounted || widget.phase != TerminalSessionPhase.ready) return;
    _readyTimer?.cancel();
    _readyTimer = null;
    _displayPhase = TerminalSessionPhase.ready;
    _startupController.stop();
    _openingController.duration = _reduceMotion
        ? _reducedOpeningDuration
        : _openingDuration;
    setState(() {});
    HapticFeedback.lightImpact();
    _playOpening();
  }

  Future<void> _playOpening() async {
    try {
      await _openingController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && widget.phase == TerminalSessionPhase.ready) {
      setState(() => _showBootGate = false);
    }
  }

  void _resetMechanicalStage() {
    _readyTimer?.cancel();
    _readyTimer = null;
    _startupController.stop();
    _startupController.value = 0;
    _openingController.stop();
    _openingController.value = 0;
    _showBootGate = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == TerminalSessionPhase.ready) {
      return _showBootGate
          ? _TerminalMechanicalGate(
              phase: _displayPhase,
              startup: _startupController,
              opening: _openingController,
              reduceMotion: _reduceMotion,
            )
          : const SizedBox.shrink();
    }
    if (widget.phase == TerminalSessionPhase.idle) {
      return _TerminalConnectPrompt(onOpen: widget.onOpen);
    }
    final pending = _isPending(widget.phase);
    if (pending) {
      return _TerminalMechanicalGate(
        phase: widget.phase,
        startup: _startupController,
        opening: _openingController,
        reduceMotion: _reduceMotion,
      );
    }
    final action =
        widget.retryable || widget.phase == TerminalSessionPhase.exited
        ? widget.onRetry
        : null;
    final scheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: scheme.scrim.withValues(alpha: 0.28),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: _label(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.94),
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon, size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _label(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          tooltip: context.tr('terminal_action_retry', 'Retry'),
                          onPressed: action,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isPending(TerminalSessionPhase value) => switch (value) {
    TerminalSessionPhase.checking ||
    TerminalSessionPhase.waking ||
    TerminalSessionPhase.creating ||
    TerminalSessionPhase.connecting ||
    TerminalSessionPhase.reconnecting => true,
    _ => false,
  };

  IconData get _icon => switch (widget.phase) {
    TerminalSessionPhase.denied => Icons.lock_outline_rounded,
    TerminalSessionPhase.capacity => Icons.groups_outlined,
    TerminalSessionPhase.exited => Icons.stop_circle_outlined,
    TerminalSessionPhase.error => Icons.error_outline_rounded,
    _ => Icons.terminal_rounded,
  };

  String _label(BuildContext context) => switch (widget.phase) {
    TerminalSessionPhase.idle => context.tr(
      'terminal_status_idle',
      'Terminal is closed',
    ),
    TerminalSessionPhase.checking => context.tr(
      'terminal_status_checking',
      'Checking workspace',
    ),
    TerminalSessionPhase.waking => context.tr(
      'terminal_status_waking',
      'Starting workspace',
    ),
    TerminalSessionPhase.creating => context.tr(
      'terminal_status_creating',
      'Creating terminal session',
    ),
    TerminalSessionPhase.connecting => context.tr(
      'terminal_status_connecting',
      'Connecting',
    ),
    TerminalSessionPhase.reconnecting => context.tr(
      'terminal_status_reconnecting',
      'Reconnecting',
    ),
    TerminalSessionPhase.exited =>
      widget.exitCode == null
          ? context.tr('terminal_status_exited', 'Process exited')
          : '${context.tr('terminal_status_exited', 'Process exited')} (${widget.exitCode})',
    TerminalSessionPhase.denied => context.tr(
      'terminal_status_denied',
      'Terminal access denied',
    ),
    TerminalSessionPhase.capacity => context.tr(
      'terminal_status_capacity',
      'Terminal session limit reached',
    ),
    TerminalSessionPhase.error => context.tr(
      'terminal_status_error',
      'Terminal connection failed',
    ),
    TerminalSessionPhase.ready => context.tr('terminal_status_ready', 'Ready'),
  };
}

class _TerminalMechanicalGate extends StatelessWidget {
  final TerminalSessionPhase phase;
  final AnimationController startup;
  final AnimationController opening;
  final bool reduceMotion;

  const _TerminalMechanicalGate({
    required this.phase,
    required this.startup,
    required this.opening,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      key: const ValueKey('terminal-boot-gate'),
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([startup, opening]),
            builder: (context, _) {
              final raw = opening.value;
              final elapsedMs =
                  startup.lastElapsedDuration?.inMilliseconds ?? 0;
              final ingress =
                  reduceMotion || phase == TerminalSessionPhase.ready
                  ? 1.0
                  : 0.18 +
                        0.82 *
                            Curves.easeOutCubic.transform(
                              (elapsedMs / 260).clamp(0.0, 1.0),
                            );
              final loop = reduceMotion ? 0.0 : startup.value;
              final pulse = reduceMotion
                  ? 0.36
                  : (math.sin(loop * math.pi * 4 - math.pi / 2) + 1) / 2;
              final breath = reduceMotion
                  ? 0.0
                  : math.sin(loop * math.pi * 2) * 1.5;
              final anticipation = reduceMotion
                  ? 0.0
                  : Curves.easeInCubic.transform(_interval(raw, 0.09, 0.20));
              final topOpening = reduceMotion
                  ? 0.0
                  : const Cubic(
                      0.16,
                      1,
                      0.3,
                      1,
                    ).transform(_interval(raw, 0.20, 0.84));
              final bottomOpening = reduceMotion
                  ? 0.0
                  : const Cubic(
                      0.16,
                      1,
                      0.3,
                      1,
                    ).transform(_interval(raw, 0.22, 0.88));
              final panelFade = reduceMotion
                  ? 1 - Curves.easeOut.transform(raw)
                  : 1 - Curves.easeOut.transform(_interval(raw, 0.68, 0.94));
              final latchFade = reduceMotion
                  ? panelFade
                  : 1 - Curves.easeOut.transform(_interval(raw, 0.09, 0.30));
              final seamFlash = raw == 0
                  ? 0.18 + pulse * 0.44
                  : raw < 0.22
                  ? 0.62 + _interval(raw, 0.09, 0.22) * 0.38
                  : 1 - _interval(raw, 0.22, 0.48);
              final compression = anticipation * 3;
              final topOffset = breath * (1 - raw) + compression;
              final bottomOffset = -breath * (1 - raw) - compression;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: (ingress * panelFade).clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: scheme.scrim.withValues(alpha: 0.18),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.52,
                      child: Opacity(
                        opacity: (ingress * panelFade).clamp(0.0, 1.0),
                        child: FractionalTranslation(
                          translation: Offset(0, -1.04 * topOpening),
                          child: Transform.translate(
                            offset: Offset(0, topOffset),
                            child: const RepaintBoundary(
                              child: _GearGatePanel(isTop: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.52,
                      child: Opacity(
                        opacity: (ingress * panelFade).clamp(0.0, 1.0),
                        child: FractionalTranslation(
                          translation: Offset(0, 1.04 * bottomOpening),
                          child: Transform.translate(
                            offset: Offset(0, bottomOffset),
                            child: const RepaintBoundary(
                              child: _GearGatePanel(isTop: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: (ingress * latchFade).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 + (1 - ingress) * 0.57,
                        child: _TerminalGearCore(
                          scheme: scheme,
                          loop: loop,
                          pulse: seamFlash.clamp(0.0, 1.0),
                          opening: raw,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: (ingress * seamFlash * panelFade).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 2,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.76),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(
                                alpha: 0.34 * seamFlash,
                              ),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 104),
                      child: Opacity(
                        opacity: (ingress * (1 - _interval(raw, 0.04, 0.22)))
                            .clamp(0.0, 1.0),
                        child: _TerminalStartupLabel(phase: phase),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TerminalGearCore extends StatelessWidget {
  final ColorScheme scheme;
  final double loop;
  final double pulse;
  final double opening;

  const _TerminalGearCore({
    required this.scheme,
    required this.loop,
    required this.pulse,
    required this.opening,
  });

  @override
  Widget build(BuildContext context) {
    final rotationWeight =
        1 - Curves.easeOut.transform(_interval(opening, 0, 0.18));
    return SizedBox.square(
      dimension: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: loop * math.pi * 2 * rotationWeight,
            child: Icon(
              Icons.settings_rounded,
              size: 58,
              color: Color.lerp(scheme.onSurfaceVariant, scheme.primary, pulse),
              shadows: [
                Shadow(
                  color: scheme.primary.withValues(alpha: 0.28 * pulse),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: -loop * math.pi * 4 * rotationWeight,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: Color.lerp(
                    scheme.outlineVariant,
                    scheme.primary,
                    pulse,
                  )!,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.22 * pulse),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: 17,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalStartupLabel extends StatelessWidget {
  final TerminalSessionPhase phase;

  const _TerminalStartupLabel({required this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (phase) {
      TerminalSessionPhase.checking => context.tr(
        'terminal_status_checking',
        'Checking workspace',
      ),
      TerminalSessionPhase.waking => context.tr(
        'terminal_status_waking',
        'Starting workspace',
      ),
      TerminalSessionPhase.creating => context.tr(
        'terminal_status_creating',
        'Creating terminal session',
      ),
      TerminalSessionPhase.connecting => context.tr(
        'terminal_status_connecting',
        'Connecting',
      ),
      TerminalSessionPhase.reconnecting => context.tr(
        'terminal_status_reconnecting',
        'Reconnecting',
      ),
      _ => context.tr('terminal_status_ready', 'Ready'),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.86),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              label,
              key: ValueKey(phase),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GearGatePanel extends StatelessWidget {
  final bool isTop;

  const _GearGatePanel({required this.isTop});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GearGatePanelPainter(
      isTop: isTop,
      scheme: Theme.of(context).colorScheme,
    ),
    size: Size.infinite,
  );
}

class _GearGatePanelPainter extends CustomPainter {
  final bool isTop;
  final ColorScheme scheme;

  const _GearGatePanelPainter({required this.isTop, required this.scheme});

  @override
  void paint(Canvas canvas, Size size) {
    const toothDepth = 8.0;
    const pitch = 28.0;
    final path = Path();

    if (isTop) {
      final edge = size.height - toothDepth;
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, edge);
      for (double x = size.width; x > 0; x -= pitch) {
        path
          ..lineTo((x - pitch * 0.22).clamp(0, size.width), edge)
          ..lineTo((x - pitch * 0.42).clamp(0, size.width), edge + toothDepth)
          ..lineTo((x - pitch * 0.68).clamp(0, size.width), edge + toothDepth)
          ..lineTo((x - pitch).clamp(0, size.width), edge);
      }
      path.close();
    } else {
      path.moveTo(0, toothDepth);
      for (double x = 0; x < size.width; x += pitch) {
        path
          ..lineTo((x + pitch * 0.22).clamp(0, size.width), toothDepth)
          ..lineTo((x + pitch * 0.42).clamp(0, size.width), 0)
          ..lineTo((x + pitch * 0.68).clamp(0, size.width), 0)
          ..lineTo((x + pitch).clamp(0, size.width), toothDepth);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }

    final bounds = Offset.zero & size;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    final edgePaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, edgePaint);

    final machiningPaint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final y = isTop ? size.height - 24 : 24.0;
    canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), machiningPaint);
  }

  @override
  bool shouldRepaint(covariant _GearGatePanelPainter oldDelegate) =>
      oldDelegate.isTop != isTop || oldDelegate.scheme != scheme;
}

double _interval(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}

class _GearDoorPowerButton extends StatelessWidget {
  final ColorScheme scheme;
  final double idle;
  final double activation;
  final bool pressed;
  final bool enabled;

  const _GearDoorPowerButton({
    required this.scheme,
    required this.idle,
    required this.activation,
    required this.pressed,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: pressed ? 0.94 : 1,
      child: SizedBox.square(
        dimension: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(88),
              painter: _GearDoorPowerPainter(
                scheme: scheme,
                idle: idle,
                activation: activation,
                pressed: pressed,
              ),
            ),
            Transform.rotate(
              angle: activation * 0.22,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Color.lerp(
                      scheme.outlineVariant,
                      scheme.primary,
                      activation,
                    )!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(
                        alpha: pressed ? 0.10 : 0.28,
                      ),
                      blurRadius: pressed ? 3 : 8,
                      offset: Offset(0, pressed ? 1 : 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 21,
                  color: enabled
                      ? Color.lerp(scheme.primary, scheme.tertiary, activation)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearDoorPowerPainter extends CustomPainter {
  final ColorScheme scheme;
  final double idle;
  final double activation;
  final bool pressed;

  const _GearDoorPowerPainter({
    required this.scheme,
    required this.idle,
    required this.activation,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = Rect.fromCircle(center: center, radius: size.width / 2 - 2);
    final inner = Rect.fromCircle(center: center, radius: size.width / 2 - 9);

    canvas.drawOval(
      outer,
      Paint()..color = scheme.shadow.withValues(alpha: pressed ? 0.10 : 0.22),
    );
    canvas.drawOval(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerLow],
        ).createShader(inner),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(inner));
    final travel = activation * 7;
    final seam = center.dy;
    final topPaint = Paint()..color = scheme.surfaceContainerHigh;
    final bottomPaint = Paint()..color = scheme.surfaceContainerLowest;
    canvas.drawRect(
      Rect.fromLTRB(inner.left, inner.top - travel, inner.right, seam - travel),
      topPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        inner.left,
        seam + travel,
        inner.right,
        inner.bottom + travel,
      ),
      bottomPaint,
    );

    const pitch = 12.0;
    const depth = 4.0;
    final topTeeth = Path()..moveTo(inner.left, seam - travel);
    final bottomTeeth = Path()..moveTo(inner.left, seam + travel);
    for (double x = inner.left; x < inner.right; x += pitch) {
      topTeeth
        ..lineTo(x + pitch * 0.28, seam - travel)
        ..lineTo(x + pitch * 0.45, seam + depth - travel)
        ..lineTo(x + pitch * 0.70, seam + depth - travel)
        ..lineTo((x + pitch).clamp(inner.left, inner.right), seam - travel);
      bottomTeeth
        ..lineTo(x + pitch * 0.28, seam + travel)
        ..lineTo(x + pitch * 0.45, seam - depth + travel)
        ..lineTo(x + pitch * 0.70, seam - depth + travel)
        ..lineTo((x + pitch).clamp(inner.left, inner.right), seam + travel);
    }
    final seamPaint = Paint()
      ..color = Color.lerp(
        scheme.outlineVariant,
        scheme.primary,
        0.18 + idle * 0.24 + activation * 0.58,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(topTeeth, seamPaint);
    canvas.drawPath(bottomTeeth, seamPaint);
    canvas.restore();

    canvas.drawOval(
      inner,
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      outer,
      -1.15,
      0.9 + idle * 0.3,
      false,
      Paint()
        ..color = scheme.primary.withValues(
          alpha: 0.22 + idle * 0.18 + activation * 0.34,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _GearDoorPowerPainter oldDelegate) =>
      oldDelegate.idle != idle ||
      oldDelegate.activation != activation ||
      oldDelegate.pressed != pressed ||
      oldDelegate.scheme != scheme;
}

class _TerminalConnectPrompt extends StatefulWidget {
  final VoidCallback? onOpen;

  const _TerminalConnectPrompt({this.onOpen});

  @override
  State<_TerminalConnectPrompt> createState() => _TerminalConnectPromptState();
}

class _TerminalConnectPromptState extends State<_TerminalConnectPrompt>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _powerController;
  bool _pressed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _powerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _powerController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (widget.onOpen == null || _starting) return;
    _starting = true;
    HapticFeedback.mediumImpact();
    await _powerController.animateTo(
      0.34,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeInCubic,
    );
    if (!mounted) return;
    widget.onOpen!();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    _starting = false;
    await _powerController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.97),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.88),
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: scheme.surface.withValues(alpha: 0.68),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _idleController,
                          _powerController,
                        ]),
                        builder: (context, _) {
                          final idle = Curves.easeInOut.transform(
                            _idleController.value,
                          );
                          final burst = Curves.easeOutCubic.transform(
                            _powerController.value,
                          );
                          return Tooltip(
                            message: context.tr(
                              'terminal_action_open',
                              'Connect terminal',
                            ),
                            child: Semantics(
                              button: true,
                              enabled: widget.onOpen != null,
                              label: context.tr(
                                'terminal_action_open',
                                'Connect terminal',
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _open,
                                onTapDown: widget.onOpen == null
                                    ? null
                                    : (_) => setState(() => _pressed = true),
                                onTapCancel: () =>
                                    setState(() => _pressed = false),
                                onTapUp: (_) =>
                                    setState(() => _pressed = false),
                                child: _GearDoorPowerButton(
                                  scheme: scheme,
                                  idle: idle,
                                  activation: burst,
                                  pressed: _pressed,
                                  enabled: widget.onOpen != null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr(
                        'terminal_status_idle',
                        'Connect to your workspace',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'terminal_idle_description',
                        'Start a command-line session in the selected workspace.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('terminal_action_open', 'Connect terminal'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
