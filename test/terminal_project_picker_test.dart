import 'package:d1vai_app/models/project.dart';
import 'package:d1vai_app/widgets/terminal/terminal_project_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _projects = <UserProject>[
  UserProject(
    id: 'alpha',
    projectName: 'Alpha console',
    projectDescription: '',
    createdAt: '2026-08-01T00:00:00Z',
    updatedAt: '2026-08-03T00:00:00Z',
    userId: 1,
    projectPort: 3000,
  ),
  UserProject(
    id: 'billing',
    projectName: 'Billing portal',
    projectDescription: '',
    createdAt: '2026-08-01T00:00:00Z',
    updatedAt: '2026-08-02T00:00:00Z',
    userId: 1,
    projectPort: 3001,
  ),
];

void main() {
  testWidgets('searches projects and returns a server-scoped project id', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalProjectPicker(
            projects: _projects,
            selectedProjectId: null,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('terminal-project-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'billing');
    await tester.pump();

    expect(find.text('Alpha console'), findsNothing);
    expect(find.text('Billing portal'), findsOneWidget);
    await tester.tap(find.text('Billing portal'));
    await tester.pumpAndSettle();

    expect(selected, 'billing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the target control at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: TerminalProjectPicker(
                projects: _projects,
                selectedProjectId: 'billing',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Billing portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
