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
                  builder: (_) => DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.5,
                    minChildSize: 0.3,
                    maxChildSize: 0.95,
                    builder: (_, scrollController) => Container(
                      key: const ValueKey('bottom-sheet-content'),
                      color: Colors.white,
                      child: ListView(
                        controller: scrollController,
                        children: const [SizedBox(height: 280)],
                      ),
                    ),
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

  testWidgets('standard mobile sheet closes when tapping outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showAdaptiveModal<void>(
                  context: context,
                  builder: (_) => const AdaptiveModalContainer(
                    child: SizedBox(
                      key: ValueKey('standard-sheet-content'),
                      height: 220,
                    ),
                  ),
                ),
                child: const Text('Open standard'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open standard'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('standard-sheet-content')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('standard-sheet-content')), findsNothing);
  });
}
