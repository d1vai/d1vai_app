import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../controllers/terminal_session_controller.dart';
import '../../l10n/app_localizations.dart';
import 'terminal_status_overlay.dart';
import 'terminal_theme.dart';

class TerminalSurface extends StatefulWidget {
  final TerminalSessionController session;
  final String targetKey;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;
  final Terminal? terminal;

  const TerminalSurface({
    super.key,
    required this.session,
    required this.targetKey,
    this.onOpen,
    this.onRetry,
    this.terminal,
  });

  @override
  State<TerminalSurface> createState() => TerminalSurfaceState();
}

class TerminalSurfaceState extends State<TerminalSurface> {
  late final Terminal terminal;
  late final TerminalController terminalController;
  late final FocusNode focusNode;
  StreamSubscription<String>? _outputSubscription;

  @override
  void initState() {
    super.initState();
    terminal = widget.terminal ?? Terminal(maxLines: 5000);
    terminalController = TerminalController();
    focusNode = FocusNode(debugLabel: 'container-terminal');
    terminal.onOutput = (data) {
      widget.session.sendInput(utf8.encode(data));
    };
    terminal.onResize = (columns, rows, _, _) {
      widget.session.updateSize(columns, rows);
    };
    _listenToOutput();
  }

  @override
  void didUpdateWidget(covariant TerminalSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      terminal.onOutput = (data) {
        widget.session.sendInput(utf8.encode(data));
      };
      _listenToOutput();
    }
    if (oldWidget.targetKey != widget.targetKey) {
      clear();
    }
  }

  void _listenToOutput() {
    _outputSubscription?.cancel();
    _outputSubscription = widget.session.output
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(terminal.write);
  }

  void clear() {
    terminal.buffer.clear();
    terminal.notifyListeners();
  }

  void requestFocus() => focusNode.requestFocus();

  @override
  void dispose() {
    _outputSubscription?.cancel();
    terminal.onOutput = null;
    terminal.onResize = null;
    terminalController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final terminalTheme = d1vTerminalTheme(brightness);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: terminalTheme.background,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Semantics(
                textField: true,
                label: context.tr(
                  'terminal_accessibility_label',
                  'Container terminal',
                ),
                child: TerminalView(
                  terminal,
                  controller: terminalController,
                  focusNode: focusNode,
                  autofocus: true,
                  theme: terminalTheme,
                  keyboardAppearance: brightness,
                  deleteDetection: true,
                  readOnly: !widget.session.acceptsInput,
                  padding: const EdgeInsets.all(10),
                  textStyle: const TerminalStyle(fontSize: 13, height: 1.25),
                ),
              ),
            ),
          ),
          TerminalStatusOverlay(
            phase: widget.session.phase,
            exitCode: widget.session.exitCode,
            retryable: widget.session.retryable,
            onOpen: widget.onOpen,
            onRetry: widget.onRetry,
          ),
        ],
      ),
    );
  }
}
