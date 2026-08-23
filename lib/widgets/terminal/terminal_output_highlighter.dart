enum TerminalOutputKind { error, warning, success }

sealed class TerminalOsc133Event {
  const TerminalOsc133Event();
}

class TerminalPromptStart extends TerminalOsc133Event {
  const TerminalPromptStart();
}

class TerminalPromptEnd extends TerminalOsc133Event {
  const TerminalPromptEnd();
}

class TerminalOutputStart extends TerminalOsc133Event {
  const TerminalOutputStart();
}

class TerminalCommandFinished extends TerminalOsc133Event {
  final int? exitCode;

  const TerminalCommandFinished(this.exitCode);
}

const _maxOsc133DataLength = 16;
const _maxControlLength = 256;
const _maxPendingLineLength = 8192;

final _errorPattern = RegExp(
  r'\b(error|fatal|failed|failure|panic|exception|traceback|uncaught)\b',
  caseSensitive: false,
);
final _warningPattern = RegExp(
  r'\b(warn|warning|deprecated|deprecation)\b',
  caseSensitive: false,
);
final _successPattern = RegExp(
  r'\b(success|successful|successfully|succeeded|passed|done|completed)\b',
  caseSensitive: false,
);

TerminalOsc133Event? parseTerminalOsc133(String data) {
  if (data.length > _maxOsc133DataLength) return null;
  if (data == 'A') return const TerminalPromptStart();
  if (data == 'B') return const TerminalPromptEnd();
  if (data == 'C') return const TerminalOutputStart();
  final match = RegExp(r'^D(?:;([0-9]{1,3}))?$').firstMatch(data);
  if (match == null) return null;
  final exitCode = match.group(1) == null ? null : int.parse(match.group(1)!);
  if (exitCode != null && exitCode > 255) return null;
  return TerminalCommandFinished(exitCode);
}

TerminalOutputKind? classifyTerminalOutputLine(String value) {
  if (_errorPattern.hasMatch(value)) return TerminalOutputKind.error;
  if (_warningPattern.hasMatch(value)) return TerminalOutputKind.warning;
  if (_successPattern.hasMatch(value)) return TerminalOutputKind.success;
  return null;
}

class TerminalOutputHighlighter {
  final StringBuffer _line = StringBuffer();
  StringBuffer? _control;
  bool _inOutput = false;
  bool _lineHasAnsi = false;
  bool _linePassthrough = false;
  bool _alternateScreen = false;

  String add(String data) {
    if (data.isEmpty) return '';
    final output = StringBuffer();
    for (final codePoint in data.runes) {
      _consumeCodePoint(codePoint, output);
    }
    return output.toString();
  }

  String reset() {
    final output = StringBuffer();
    final control = _control;
    if (control != null) output.write(control);
    _control = null;
    _flushLine(output, highlight: false);
    _inOutput = false;
    _lineHasAnsi = false;
    _linePassthrough = false;
    _alternateScreen = false;
    return output.toString();
  }

  void _consumeCodePoint(int codePoint, StringBuffer output) {
    final control = _control;
    if (control != null) {
      control.writeCharCode(codePoint);
      final value = control.toString();
      if (_controlComplete(value)) {
        _control = null;
        _handleControl(value, output);
      } else if (value.length >= _maxControlLength) {
        _control = null;
        _emit(value, output, ansi: true);
      }
      return;
    }

    if (codePoint == 0x1B) {
      _control = StringBuffer()..writeCharCode(codePoint);
      return;
    }
    _emit(String.fromCharCode(codePoint), output);
  }

  bool _controlComplete(String value) {
    if (value.length < 2) return false;
    if (value.startsWith('\x1b]')) {
      return value.endsWith('\x07') || value.endsWith('\x1b\\');
    }
    if (value.startsWith('\x1b[')) {
      final last = value.codeUnitAt(value.length - 1);
      return value.length > 2 && last >= 0x40 && last <= 0x7E;
    }
    return true;
  }

  void _handleControl(String value, StringBuffer output) {
    final oscData = _osc133Data(value);
    if (oscData != null && !_alternateScreen) {
      final event = parseTerminalOsc133(oscData);
      if (event is TerminalOutputStart) {
        _flushLine(output, highlight: false);
        output.write(value);
        _inOutput = true;
        return;
      }
      if (event is TerminalCommandFinished) {
        _flushLine(output, highlight: false);
        output.write(value);
        _inOutput = false;
        return;
      }
      if (event != null) {
        output.write(value);
        return;
      }
    }

    final wasAlternateScreen = _alternateScreen;
    _updateAlternateScreen(value);
    if (wasAlternateScreen || _alternateScreen) {
      output.write(value);
      return;
    }
    _emit(value, output, ansi: true);
  }

  String? _osc133Data(String value) {
    if (!value.startsWith('\x1b]133;')) return null;
    final terminatorLength = value.endsWith('\x1b\\') ? 2 : 1;
    return value.substring(6, value.length - terminatorLength);
  }

  void _updateAlternateScreen(String value) {
    if (!value.startsWith('\x1b[')) return;
    if (RegExp(r'^\x1b\[\?(47|1047|1049)h$').hasMatch(value)) {
      _alternateScreen = true;
      return;
    }
    if (RegExp(r'^\x1b\[\?(47|1047|1049)l$').hasMatch(value)) {
      _alternateScreen = false;
    }
  }

  void _emit(String value, StringBuffer output, {bool ansi = false}) {
    if (!_inOutput || _alternateScreen) {
      output.write(value);
      return;
    }
    if (_linePassthrough) {
      output.write(value);
      if (value == '\n') _resetLineState();
      return;
    }
    if (ansi) _lineHasAnsi = true;
    if (value == '\r') {
      _line.write(value);
      _flushLine(output, highlight: false);
      _linePassthrough = true;
      return;
    }
    _line.write(value);
    if (value == '\n') {
      _flushLine(output, highlight: true);
      return;
    }
    if (_line.length >= _maxPendingLineLength) {
      _flushLine(output, highlight: false);
      _linePassthrough = true;
    }
  }

  void _flushLine(StringBuffer output, {required bool highlight}) {
    if (_line.isEmpty) {
      _resetLineState();
      return;
    }
    final value = _line.toString();
    if (!highlight || _lineHasAnsi || _alternateScreen) {
      output.write(value);
      _line.clear();
      _resetLineState();
      return;
    }
    final content = value.endsWith('\n')
        ? value.substring(0, value.length - 1)
        : value;
    final kind = classifyTerminalOutputLine(content);
    final color = switch (kind) {
      TerminalOutputKind.error => '\x1b[31m',
      TerminalOutputKind.warning => '\x1b[33m',
      TerminalOutputKind.success => '\x1b[32m',
      null => null,
    };
    if (color == null || content.trim().isEmpty) {
      output.write(value);
    } else {
      output
        ..write(color)
        ..write(content)
        ..write('\x1b[39m');
      if (value.endsWith('\n')) output.write('\n');
    }
    _line.clear();
    _resetLineState();
  }

  void _resetLineState() {
    _lineHasAnsi = false;
    _linePassthrough = false;
  }
}
