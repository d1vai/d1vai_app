import 'package:d1vai_app/widgets/terminal/terminal_output_pump.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains output in bounded ordered chunks', () {
    final initial = <void Function()>[];
    final continuations = <void Function()>[];
    final written = <String>[];
    final pump = TerminalOutputPump(
      write: written.add,
      schedule: initial.add,
      scheduleContinuation: continuations.add,
      maxCodeUnitsPerDrain: 8,
    );

    pump.add('first-');
    pump.add('second-');
    pump.add('third');
    expect(initial, hasLength(1));
    expect(continuations, isEmpty);

    initial.single();
    expect(written.join(), 'first-se');
    expect(continuations, hasLength(1));

    while (continuations.isNotEmpty) {
      continuations.removeAt(0)();
      expect(written.last.length, lessThanOrEqualTo(8));
    }

    expect(written.join(), 'first-second-third');
    expect(pump.hasPendingOutput, isFalse);
  });

  test('never divides a UTF-16 surrogate pair', () {
    final scheduled = <void Function()>[];
    final written = <String>[];
    final pump = TerminalOutputPump(
      write: written.add,
      schedule: scheduled.add,
      maxCodeUnitsPerDrain: 2,
    );

    pump.add('A🚀B🙂C');
    while (scheduled.isNotEmpty) {
      scheduled.removeAt(0)();
    }

    expect(written.join(), 'A🚀B🙂C');
    for (final chunk in written) {
      expect(chunk.runes, isNot(contains(0xFFFD)));
    }
  });

  test('clear and dispose discard stale scheduled output', () {
    final scheduled = <void Function()>[];
    final written = <String>[];
    final pump = TerminalOutputPump(
      write: written.add,
      schedule: scheduled.add,
      maxCodeUnitsPerDrain: 4,
    );

    pump.add('stale-output');
    pump.clear();
    scheduled.removeAt(0)();
    expect(written, isEmpty);

    pump.add('also-stale');
    pump.dispose();
    scheduled.removeAt(0)();
    expect(written, isEmpty);
    expect(pump.hasPendingOutput, isFalse);
  });
}
