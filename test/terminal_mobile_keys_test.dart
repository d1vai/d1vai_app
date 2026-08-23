import 'package:d1vai_app/widgets/terminal/terminal_mobile_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('mobile accessory sends keys and exposes clipboard actions', (
    tester,
  ) async {
    final keys = <TerminalKey>[];
    var ctrlToggles = 0;
    var copies = 0;
    var pastes = 0;
    var hides = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: TerminalMobileKeys(
              enabled: true,
              ctrlArmed: false,
              onCtrlToggle: () => ctrlToggles += 1,
              onKey: keys.add,
              onCopy: () => copies += 1,
              onPaste: () => pastes += 1,
              onHideKeyboard: () => hides += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('terminal-key-ctrl')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-tab')));
    expect(ctrlToggles, 1);
    expect(keys, <TerminalKey>[TerminalKey.tab]);

    await tester.drag(find.byType(ListView), const Offset(-800, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-key-copy')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-paste')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-hide-keyboard')));

    expect(copies, 1);
    expect(pastes, 1);
    expect(hides, 1);
    expect(tester.takeException(), isNull);
  });
}
