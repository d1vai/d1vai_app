import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../l10n/app_localizations.dart';

class TerminalMobileKeys extends StatelessWidget {
  final bool enabled;
  final bool ctrlArmed;
  final VoidCallback onCtrlToggle;
  final ValueChanged<TerminalKey> onKey;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onHideKeyboard;

  const TerminalMobileKeys({
    super.key,
    required this.enabled,
    required this.ctrlArmed,
    required this.onCtrlToggle,
    required this.onKey,
    required this.onCopy,
    required this.onPaste,
    required this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            children: [
              _TextKey(
                controlKey: 'esc',
                label: 'Esc',
                tooltip: context.tr('terminal_key_escape', 'Escape'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.escape),
              ),
              _TextKey(
                controlKey: 'ctrl',
                label: 'Ctrl',
                tooltip: context.tr('terminal_key_control', 'Control'),
                enabled: enabled,
                selected: ctrlArmed,
                onPressed: onCtrlToggle,
              ),
              _TextKey(
                controlKey: 'tab',
                label: 'Tab',
                tooltip: context.tr('terminal_key_tab', 'Tab completion'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.tab),
              ),
              _IconKey(
                controlKey: 'left',
                icon: Icons.arrow_back_rounded,
                tooltip: context.tr('terminal_key_left', 'Left'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.arrowLeft),
              ),
              _IconKey(
                controlKey: 'up',
                icon: Icons.arrow_upward_rounded,
                tooltip: context.tr('terminal_key_up', 'Previous command'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.arrowUp),
              ),
              _IconKey(
                controlKey: 'down',
                icon: Icons.arrow_downward_rounded,
                tooltip: context.tr('terminal_key_down', 'Next command'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.arrowDown),
              ),
              _IconKey(
                controlKey: 'right',
                icon: Icons.arrow_forward_rounded,
                tooltip: context.tr(
                  'terminal_key_right',
                  'Right or accept suggestion',
                ),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.arrowRight),
              ),
              _TextKey(
                controlKey: 'home',
                label: 'Home',
                tooltip: context.tr('terminal_key_home', 'Home'),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.home),
              ),
              _TextKey(
                controlKey: 'end',
                label: 'End',
                tooltip: context.tr(
                  'terminal_key_end',
                  'End or accept suggestion',
                ),
                enabled: enabled,
                onPressed: () => onKey(TerminalKey.end),
              ),
              _IconKey(
                controlKey: 'copy',
                icon: Icons.copy_rounded,
                tooltip: context.tr('terminal_action_copy', 'Copy selection'),
                enabled: enabled,
                onPressed: onCopy,
              ),
              _IconKey(
                controlKey: 'paste',
                icon: Icons.content_paste_rounded,
                tooltip: context.tr('terminal_action_paste', 'Paste'),
                enabled: enabled,
                onPressed: onPaste,
              ),
              _IconKey(
                controlKey: 'hide-keyboard',
                icon: Icons.keyboard_hide_rounded,
                tooltip: context.tr(
                  'terminal_action_hide_keyboard',
                  'Hide keyboard',
                ),
                enabled: true,
                onPressed: onHideKeyboard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextKey extends StatelessWidget {
  final String controlKey;
  final String label;
  final String tooltip;
  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  const _TextKey({
    required this.controlKey,
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: selected,
          label: tooltip,
          child: TextButton(
            key: ValueKey('terminal-key-$controlKey'),
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  final String controlKey;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _IconKey({
    required this.controlKey,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        key: ValueKey('terminal-key-$controlKey'),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
