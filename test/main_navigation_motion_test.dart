import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/dashboard_screen.dart';
import 'package:d1vai_app/screens/main_screen.dart';
import 'package:d1vai_app/screens/terminal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom navigation selection animates inside fixed tab bounds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
          ChangeNotifierProvider(create: (_) => OrganizationProvider()),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pump();

    AnimatedContainer selectionFor(int index) =>
        tester.widget(find.byKey(ValueKey('main-nav-selection-$index')));

    final dashboardSelection = selectionFor(0);
    final dashboardDecoration = dashboardSelection.decoration! as BoxDecoration;
    expect(dashboardDecoration.color!.a, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('main-nav-item-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final terminalSelection = selectionFor(1);
    final terminalDecoration = terminalSelection.decoration! as BoxDecoration;
    expect(terminalDecoration.color!.a, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(TerminalScreen), findsOneWidget);

    for (final index in const [0, 1, 0]) {
      await tester.tap(find.byKey(ValueKey('main-nav-item-$index')));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
