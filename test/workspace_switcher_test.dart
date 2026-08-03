import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/models/organization.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/services/organization_service.dart';
import 'package:d1vai_app/widgets/organization/workspace_switcher.dart';

class _SwitcherOrganizationService extends OrganizationService {
  @override
  Future<OrganizationContextData> getContext() async {
    return const OrganizationContextData(
      personal: PersonalWorkspaceSummary(
        id: 1,
        slug: 'dev',
        name: 'Personal',
        picture: '',
        projectCount: 1,
      ),
      organizations: [
        OrganizationSummary(
          id: 7,
          slug: 'acme-design',
          name: 'Acme Design Studio',
          picture: '',
          role: 'owner',
          projectCount: 4,
        ),
      ],
    );
  }
}

Future<void> _pumpSwitcher(
  WidgetTester tester, {
  required Size size,
  required bool expanded,
}) async {
  SharedPreferences.setMockInitialValues({'active_organization_id': 7});
  final provider = OrganizationProvider(
    service: _SwitcherOrganizationService(),
  );
  await provider.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.teal,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleProvider.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: expanded ? 240 : 220,
              child: WorkspaceSwitcher(expanded: expanded),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile workspace switcher fits and shows active organization', (
    tester,
  ) async {
    await _pumpSwitcher(tester, size: const Size(390, 844), expanded: false);
    expect(find.text('Acme Design Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop workspace switcher shows organization role', (
    tester,
  ) async {
    await _pumpSwitcher(tester, size: const Size(1200, 800), expanded: true);
    expect(find.text('Acme Design Studio'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
