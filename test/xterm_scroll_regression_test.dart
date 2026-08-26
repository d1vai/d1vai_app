import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('keeps the buffer valid after Codex-style inline history scrolling', () {
    final terminal = Terminal(maxLines: 5000)..resize(110, 25);
    for (var row = 1; row <= 25; row++) {
      terminal.write('old-$row\r\n');
    }

    terminal.write('\x1b[19;25r\x1b[19;1H\x1bM\x1bM\x1b[r');
    terminal.write('\x1b[1;20r\x1b[18;1H');
    terminal.write('\r\n\r\n> hello from inline history\r\n\r\n');
    terminal.write('\x1b[r');
    terminal.write('\x1b[1;20r\x1b[2S\x1b[r');
    terminal.write('\x1b[19;1H\x1b[J');

    expect(terminal.buffer.getText(), contains('hello from inline history'));
  });
}
