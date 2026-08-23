import 'package:flutter/material.dart';

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
    final pending = _isPending(phase);
    final action = phase == TerminalSessionPhase.idle
        ? onOpen
        : retryable || phase == TerminalSessionPhase.exited
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
                          tooltip: phase == TerminalSessionPhase.idle
                              ? context.tr(
                                  'terminal_action_open',
                                  'Open terminal',
                                )
                              : context.tr('terminal_action_retry', 'Retry'),
                          onPressed: action,
                          icon: Icon(
                            phase == TerminalSessionPhase.idle
                                ? Icons.play_arrow_rounded
                                : Icons.refresh_rounded,
                          ),
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
