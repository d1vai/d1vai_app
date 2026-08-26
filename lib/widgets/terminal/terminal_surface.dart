import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../controllers/terminal_session_controller.dart';
import '../../l10n/app_localizations.dart';
import 'terminal_status_overlay.dart';
import 'terminal_theme.dart';
import 'terminal_output_highlighter.dart';
import 'terminal_output_pump.dart';

class TerminalSurface extends StatefulWidget {
  final TerminalSessionController session;
  final String targetKey;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;
  final Terminal? terminal;
  final bool oneShotCtrl;
  final VoidCallback? onOneShotCtrlConsumed;

  const TerminalSurface({
    super.key,
    required this.session,
    required this.targetKey,
    this.onOpen,
    this.onRetry,
    this.terminal,
    this.oneShotCtrl = false,
    this.onOneShotCtrlConsumed,
  });

  @override
  State<TerminalSurface> createState() => TerminalSurfaceState();
}

class TerminalSurfaceState extends State<TerminalSurface> {
  static const closeTransitionDuration = Duration(milliseconds: 1120);

  late final Terminal terminal;
  late final TerminalController terminalController;
  late final FocusNode focusNode;
  StreamSubscription<String>? _outputSubscription;
  bool _bypassOneShotCtrl = false;
  bool _oneShotCtrlConsumed = false;
  final TerminalOutputHighlighter _outputHighlighter =
      TerminalOutputHighlighter();
  late final TerminalOutputPump _outputPump;

  @override
  void initState() {
    super.initState();
    terminal = widget.terminal ?? Terminal(maxLines: 5000);
    terminalController = TerminalController();
    focusNode = FocusNode(debugLabel: 'container-terminal');
    _outputPump = TerminalOutputPump(
      write: (data) {
        final highlighted = _outputHighlighter.add(data);
        if (highlighted.isNotEmpty) terminal.write(highlighted);
      },
      schedule: scheduleMicrotask,
      scheduleContinuation: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) callback();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
    terminal.onOutput = _handleTerminalOutput;
    terminal.onResize = (columns, rows, _, _) {
      widget.session.updateSize(columns, rows);
    };
    _listenToOutput();
  }

  @override
  void didUpdateWidget(covariant TerminalSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.oneShotCtrl || !oldWidget.oneShotCtrl) {
      _oneShotCtrlConsumed = false;
    }
    if (oldWidget.session != widget.session) {
      terminal.onOutput = _handleTerminalOutput;
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
        .listen(_outputPump.add);
  }

  void clear() {
    _outputPump.clear();
    _outputHighlighter.reset();
    terminal.useMainBuffer();
    terminal.setOriginMode(false);
    terminal.buffer.resetVerticalMargins();
    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);
    terminal.clearAltBuffer();
    terminalController.clearSelection();
    terminal.notifyListeners();
  }

  void requestFocus() => focusNode.requestFocus();

  void sendKey(TerminalKey key, {bool ctrl = false}) {
    if (!widget.session.acceptsInput) return;
    final applyOneShotCtrl = _hasOneShotCtrl;
    terminal.keyInput(key, ctrl: ctrl || applyOneShotCtrl);
    if (applyOneShotCtrl) _consumeOneShotCtrl();
    requestFocus();
  }

  Future<void> copySelection() async {
    final selection = terminalController.selection;
    if (selection == null) return;
    final text = terminal.buffer.getText(selection);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> pasteClipboard() async {
    if (!widget.session.acceptsInput) return;
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    final text = value?.text ?? '';
    if (text.isEmpty) return;
    _bypassOneShotCtrl = true;
    try {
      terminal.paste(text);
    } finally {
      _bypassOneShotCtrl = false;
    }
    if (_hasOneShotCtrl) _consumeOneShotCtrl();
    requestFocus();
  }

  void hideKeyboard() => focusNode.unfocus();

  void _handleTerminalOutput(String data) {
    if (!_hasOneShotCtrl || _bypassOneShotCtrl) {
      widget.session.sendInput(utf8.encode(data));
      return;
    }
    final runes = data.runes.toList(growable: false);
    if (runes.length == 1) {
      final code = runes.single;
      final lower = code >= 0x41 && code <= 0x5A ? code + 0x20 : code;
      if (lower >= 0x61 && lower <= 0x7A) {
        widget.session.sendInput(<int>[lower - 0x60]);
        _consumeOneShotCtrl();
        return;
      }
      if (code >= 0x5B && code <= 0x5F) {
        widget.session.sendInput(<int>[code - 0x40]);
        _consumeOneShotCtrl();
        return;
      }
    }
    widget.session.sendInput(utf8.encode(data));
    _consumeOneShotCtrl();
  }

  bool get _hasOneShotCtrl => widget.oneShotCtrl && !_oneShotCtrlConsumed;

  void _consumeOneShotCtrl() {
    if (!_hasOneShotCtrl) return;
    _oneShotCtrlConsumed = true;
    widget.onOneShotCtrlConsumed?.call();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _outputPump.dispose();
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
                  autofocus: false,
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
