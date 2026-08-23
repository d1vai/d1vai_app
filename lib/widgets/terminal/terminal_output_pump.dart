import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef TerminalOutputScheduler = void Function(VoidCallback callback);

class TerminalOutputPump {
  final ValueChanged<String> write;
  final TerminalOutputScheduler schedule;
  final TerminalOutputScheduler scheduleContinuation;
  final int maxCodeUnitsPerDrain;

  final Queue<String> _queue = Queue<String>();
  int _headOffset = 0;
  bool _scheduled = false;
  bool _disposed = false;

  TerminalOutputPump({
    required this.write,
    required this.schedule,
    TerminalOutputScheduler? scheduleContinuation,
    this.maxCodeUnitsPerDrain = 16 * 1024,
  }) : scheduleContinuation = scheduleContinuation ?? schedule,
       assert(maxCodeUnitsPerDrain >= 2);

  bool get hasPendingOutput => _queue.isNotEmpty;

  void add(String data) {
    if (_disposed || data.isEmpty) return;
    _queue.addLast(data);
    _ensureScheduled(schedule);
  }

  void clear() {
    _queue.clear();
    _headOffset = 0;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    clear();
  }

  void _ensureScheduled(TerminalOutputScheduler scheduler) {
    if (_scheduled || _disposed || _queue.isEmpty) return;
    _scheduled = true;
    scheduler(_drain);
  }

  void _drain() {
    _scheduled = false;
    if (_disposed || _queue.isEmpty) return;

    var remaining = maxCodeUnitsPerDrain;
    while (remaining > 0 && _queue.isNotEmpty) {
      final value = _queue.first;
      var end = (_headOffset + remaining).clamp(_headOffset, value.length);
      if (end < value.length && end > _headOffset) {
        final lastCodeUnit = value.codeUnitAt(end - 1);
        if (_isHighSurrogate(lastCodeUnit)) end -= 1;
      }
      if (end == _headOffset) {
        end = (_headOffset + 2).clamp(_headOffset, value.length);
      }

      final chunk = value.substring(_headOffset, end);
      write(chunk);
      remaining -= chunk.length;
      _headOffset = end;
      if (_headOffset == value.length) {
        _queue.removeFirst();
        _headOffset = 0;
      }
    }

    _ensureScheduled(scheduleContinuation);
  }
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
