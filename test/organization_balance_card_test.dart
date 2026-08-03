import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/models/balance.dart';
import 'package:d1vai_app/models/organization.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/services/organization_service.dart';
import 'package:d1vai_app/services/wallet_service.dart';
import 'package:d1vai_app/widgets/balance_card.dart';

class _BalanceOrganizationService extends OrganizationService {
  @override
  Future<OrganizationContextData> getContext() async =>
      const OrganizationContextData(
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
            slug: 'acme',
            name: 'Acme',
            picture: '',
            role: 'owner',
            projectCount: 2,
          ),
        ],
      );

  @override
  Future<OrganizationWalletInfo> getWallet(String slug) async =>
      const OrganizationWalletInfo(
        expiringBalance: 2,
        nonexpiringBalance: 3,
        canManage: true,
      );
}

class _BalanceWalletService extends WalletService {
  @override
  Future<BalanceResponse> getBalance() async => BalanceResponse(
    balanceExpiringUsd: 4,
    balanceNonExpiringUsd: 6,
    totalBalanceUsd: 10,
  );
}

Future<void> _pumpBalance(
  WidgetTester tester, {
  required bool organization,
}) async {
  SharedPreferences.setMockInitialValues({
    if (organization) 'active_organization_id': 7,
  });
  final organizationService = _BalanceOrganizationService();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => OrganizationProvider(service: organizationService),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleProvider.supportedLocales,
        home: Scaffold(
          body: BalanceCard(
            walletService: _BalanceWalletService(),
            organizationService: organizationService,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('personal balance offers irreversible organization transfer', (
    tester,
  ) async {
    await _pumpBalance(tester, organization: false);

    expect(find.text(r'$10.00'), findsOneWidget);
    expect(find.text('Transfer balance'), findsOneWidget);
    expect(find.text('Top up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organization balance hides personal funding actions', (
    tester,
  ) async {
    await _pumpBalance(tester, organization: true);

    expect(find.text('Acme'), findsOneWidget);
    expect(find.text(r'$5.00'), findsOneWidget);
    expect(find.text('Transfer balance'), findsNothing);
    expect(find.text('Top up'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
