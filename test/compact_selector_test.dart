import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d1vai_app/widgets/compact_selector.dart';

void main() {
  testWidgets('CompactSelector tolerates maxWidth smaller than minWidth', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CompactSelector(
              options: const [
                CompactSelectorOption(value: 'a', label: 'Alpha'),
              ],
              value: 'a',
              minWidth: 82,
              maxWidth: 9.9,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CompactSelector), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
