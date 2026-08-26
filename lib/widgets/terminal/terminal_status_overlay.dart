import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/terminal_session_controller.dart';
import '../../l10n/app_localizations.dart';

class TerminalStatusOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (phase == TerminalSessionPhase.ready) {
      return const SizedBox.shrink();
    }
    if (phase == TerminalSessionPhase.idle) {
      return _TerminalConnectPrompt(onOpen: onOpen);
    }
    final pending = _isPending(phase);
    final action = retryable || phase == TerminalSessionPhase.exited
        ? onRetry
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
                      if (pending)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
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

  IconData get _icon => switch (phase) {
    TerminalSessionPhase.denied => Icons.lock_outline_rounded,
    TerminalSessionPhase.capacity => Icons.groups_outlined,
    TerminalSessionPhase.exited => Icons.stop_circle_outlined,
    TerminalSessionPhase.error => Icons.error_outline_rounded,
    _ => Icons.terminal_rounded,
  };

  String _label(BuildContext context) => switch (phase) {
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
      exitCode == null
          ? context.tr('terminal_status_exited', 'Process exited')
          : '${context.tr('terminal_status_exited', 'Process exited')} ($exitCode)',
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

  void _open() {
    if (widget.onOpen == null) return;
    HapticFeedback.mediumImpact();
    _powerController.forward(from: 0);
    widget.onOpen!();
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
                                child: SizedBox.square(
                                  dimension: 78,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scale:
                                            0.88 + idle * 0.18 + burst * 0.25,
                                        child: Opacity(
                                          opacity:
                                              (0.28 * (1 - burst)) +
                                              idle * 0.14,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                width: 1.5,
                                                color: scheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: _pressed ? 0.93 : 1,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                scheme.surfaceContainerHighest,
                                                scheme.surfaceContainerLow,
                                              ],
                                            ),
                                            border: Border.all(
                                              color: scheme.outlineVariant,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: scheme.shadow.withValues(
                                                  alpha: _pressed ? 0.10 : 0.24,
                                                ),
                                                blurRadius: _pressed ? 4 : 10,
                                                offset: Offset(
                                                  0,
                                                  _pressed ? 2 : 5,
                                                ),
                                              ),
                                              BoxShadow(
                                                color: scheme.surface
                                                    .withValues(alpha: 0.62),
                                                blurRadius: 1,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.power_settings_new_rounded,
                                            size: 27,
                                            color: widget.onOpen == null
                                                ? scheme.onSurfaceVariant
                                                : Color.lerp(
                                                    scheme.primary,
                                                    scheme.tertiary,
                                                    burst,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
