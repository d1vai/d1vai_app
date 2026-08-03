import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/models/organization.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/screens/organization_invitation_screen.dart';
import 'package:d1vai_app/services/organization_service.dart';

class _InvitationService extends OrganizationService {
  final String status;

  _InvitationService(this.status);

  @override
  Future<OrganizationInvitationPreview> previewInvitation(String token) async {
    return OrganizationInvitationPreview(
      slug: 'acme',
      name: 'Acme',
      picture: '',
      emailHint: 'd***@d1v.ai',
      status: status,
      expiresAt: DateTime(2026, 8, 10),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required String status,
  required Locale locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleProvider.supportedLocales,
      home: OrganizationInvitationScreen(
        token: 'test-token',
        service: _InvitationService(status),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('revoked invitation has a terminal English state', (
    tester,
  ) async {
    await _pump(tester, status: 'revoked', locale: const Locale('en'));

    expect(find.text('Invitation revoked'), findsOneWidget);
    expect(find.text('Join organization'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired invitation is localized in Chinese', (tester) async {
    await _pump(tester, status: 'expired', locale: const Locale('zh'));

    expect(find.text('邀请已过期'), findsOneWidget);
    expect(find.text('请联系组织所有者重新发送邀请。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
