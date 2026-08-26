import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard search morphs between open and close states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
          ChangeNotifierProvider(create: (_) => OrganizationProvider()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    const openKey = ValueKey('dashboard-search-open');
    const closeKey = ValueKey('dashboard-search-close');
    const fieldKey = ValueKey('dashboard-search-field');

    expect(find.byKey(openKey), findsOneWidget);
    expect(find.byKey(fieldKey), findsNothing);

    await tester.tap(find.byKey(openKey));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(openKey), findsOneWidget);
    expect(find.byKey(closeKey), findsOneWidget);
    expect(find.byKey(fieldKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(openKey), findsNothing);
    expect(find.byKey(closeKey), findsOneWidget);

    await tester.tap(find.byKey(closeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byKey(fieldKey), findsNothing);
    expect(find.byKey(closeKey), findsNothing);
    expect(find.byKey(openKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
