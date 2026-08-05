import 'package:d1vai_app/widgets/adaptive_modal.dart';
import 'package:d1vai_app/widgets/app_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium glass surface provisions its own layer by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppGlassSurface(child: SizedBox.expand())),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('draggable bottom sheet closes when tapping outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showAdaptiveDraggableSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    key: ValueKey('bottom-sheet-content'),
                    height: 280,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-sheet-content')), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bottom-sheet-content')), findsNothing);
  });
}
