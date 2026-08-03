import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/models/organization.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/screens/organization_screen.dart';
import 'package:d1vai_app/services/organization_service.dart';

class _OrganizationScreenService extends OrganizationService {
  final String role;

  _OrganizationScreenService({this.role = 'owner'});

  OrganizationContextData get fixture => OrganizationContextData(
    personal: const PersonalWorkspaceSummary(
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
        role: role,
        projectCount: 4,
      ),
    ],
  );

  @override
  Future<OrganizationContextData> getContext() async => fixture;

  @override
  Future<Map<String, dynamic>> getOrganization(String slug) async => {
    'name': 'Acme Design Studio',
    'website': 'https://www.d1v.ai',
    'description': 'A shared product workspace',
  };

  @override
  Future<List<OrganizationMemberInfo>> getMembers(String slug) async => const [
    OrganizationMemberInfo(
      id: 1,
      email: 'owner@d1v.ai',
      picture: '',
      role: 'owner',
    ),
    OrganizationMemberInfo(
      id: 2,
      email: 'member@d1v.ai',
      picture: '',
      role: 'member',
    ),
  ];

  @override
  Future<OrganizationWalletInfo> getWallet(String slug) async =>
      const OrganizationWalletInfo(
        expiringBalance: 1,
        nonexpiringBalance: 4,
        canManage: true,
      );

  @override
  Future<List<OrganizationInvitationInfo>> getInvitations(String slug) async =>
      [
        OrganizationInvitationInfo(
          id: 1,
          email: 'invited@d1v.ai',
          status: 'pending',
          expiresAt: DateTime(2026, 8, 10),
        ),
      ];
}

Future<void> _pumpOrganizationScreen(
  WidgetTester tester, {
  required Size size,
  required ThemeMode themeMode,
  String role = 'owner',
}) async {
  SharedPreferences.setMockInitialValues({'active_organization_id': 7});
  final service = _OrganizationScreenService(role: role);
  final provider = OrganizationProvider(service: service);
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
        themeMode: themeMode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleProvider.supportedLocales,
        home: OrganizationScreen(slug: 'acme-design', service: service),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('organization management fits mobile light mode', (tester) async {
    await _pumpOrganizationScreen(
      tester,
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    expect(find.text('Acme Design Studio'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
    expect(find.text('Transfer balance'), findsOneWidget);
    expect(find.text('Transfer a project'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organization management renders desktop dark mode', (
    tester,
  ) async {
    await _pumpOrganizationScreen(
      tester,
      size: const Size(1200, 900),
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Invitation sent'), findsNothing);
    expect(find.text('invited@d1v.ai'), findsOneWidget);
    expect(find.byTooltip('Resend invitation'), findsOneWidget);
    expect(find.byTooltip('Revoke invitation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member sees read-only organization controls', (tester) async {
    await _pumpOrganizationScreen(
      tester,
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
      role: 'member',
    );

    expect(find.text('Transfer balance'), findsNothing);
    expect(find.text('Transfer a project'), findsNothing);
    expect(find.text('Leave organization'), findsOneWidget);
    expect(find.byTooltip('Member actions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
