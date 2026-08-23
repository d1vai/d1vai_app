import 'package:d1vai_app/widgets/terminal/terminal_output_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

const _oscC = '\x1b]133;C\x07';
const _oscD = '\x1b]133;D;0\x07';

void main() {
  test('parses only bounded OSC 133 events and exit codes', () {
    expect(parseTerminalOsc133('A'), isA<TerminalPromptStart>());
    expect(parseTerminalOsc133('B'), isA<TerminalPromptEnd>());
    expect(parseTerminalOsc133('C'), isA<TerminalOutputStart>());
    expect(
      (parseTerminalOsc133('D;130') as TerminalCommandFinished).exitCode,
      130,
    );
    expect(parseTerminalOsc133('D;256'), isNull);
    expect(parseTerminalOsc133('D;nope'), isNull);
    expect(parseTerminalOsc133(List.filled(17, 'A').join()), isNull);
  });

  test('classifies output with error priority', () {
    expect(
      classifyTerminalOutputLine('warning: failed to build'),
      TerminalOutputKind.error,
    );
    expect(
      classifyTerminalOutputLine('deprecated option'),
      TerminalOutputKind.warning,
    );
    expect(
      classifyTerminalOutputLine('12 tests passed'),
      TerminalOutputKind.success,
    );
    expect(classifyTerminalOutputLine('building package'), isNull);
  });

  test('highlights only complete plain command output lines', () {
    final highlighter = TerminalOutputHighlighter();
    expect(highlighter.add('prompt error '), 'prompt error ');
    expect(highlighter.add(_oscC), _oscC);
    expect(highlighter.add('warn'), isEmpty);
    expect(
      highlighter.add('ing: old API\n'),
      '\x1b[33mwarning: old API\x1b[39m\n',
    );
    expect(
      highlighter.add('all tests passed\n'),
      '\x1b[32mall tests passed\x1b[39m\n',
    );
    expect(highlighter.add(_oscD), _oscD);
    expect(highlighter.add('prompt failed'), 'prompt failed');
  });

  test('preserves ANSI, carriage updates, and alternate screens', () {
    final highlighter = TerminalOutputHighlighter();
    final ansi = '$_oscC\x1b[31merror\x1b[0m\n';
    expect(highlighter.add(ansi), ansi);
    expect(
      highlighter.add('warning 10%\rwarning 20%\r'),
      'warning 10%\rwarning 20%\r',
    );
    const alternate = '\x1b[?1049herror plain\n\x1b[?1049l';
    expect(highlighter.add(alternate), alternate);
    expect(highlighter.add(_oscD), _oscD);
  });

  test('handles split OSC markers and reset without losing bytes', () {
    final highlighter = TerminalOutputHighlighter();
    expect(highlighter.add('\x1b]133;'), isEmpty);
    expect(highlighter.add('C\x07'), _oscC);
    expect(highlighter.add('\x1b]133;D;0'), isEmpty);
    expect(highlighter.add('\x07'), _oscD);
    expect(highlighter.add(_oscC), _oscC);
    expect(highlighter.add('unfinished error'), isEmpty);
    expect(highlighter.reset(), 'unfinished error');
  });

  test('keeps 100-line semantic batches within the paint budget', () {
    final highlighter = TerminalOutputHighlighter();
    highlighter.add(_oscC);
    final batch = List.generate(
      100,
      (index) => index.isEven
          ? 'error: failed item $index\n'
          : 'completed item $index\n',
    ).join();
    final elapsedMicros = <int>[];
    for (var batchIndex = 0; batchIndex < 50; batchIndex += 1) {
      final stopwatch = Stopwatch()..start();
      final result = highlighter.add(batch);
      stopwatch.stop();
      expect(result, isNotEmpty);
      elapsedMicros.add(stopwatch.elapsedMicroseconds);
    }
    elapsedMicros.sort();
    final p95 = elapsedMicros[(elapsedMicros.length * 0.95).floor()];
    expect(p95, lessThanOrEqualTo(16000));
  });
}
