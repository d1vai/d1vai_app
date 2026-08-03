import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/models/organization.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/services/organization_service.dart';

class _FakeOrganizationService extends OrganizationService {
  OrganizationContextData contextData;

  _FakeOrganizationService(this.contextData);

  @override
  Future<OrganizationContextData> getContext() async => contextData;

  @override
  Future<OrganizationSummary> createOrganization({
    required String name,
    required String slug,
    String? website,
    String? description,
    String? picture,
  }) async {
    final organization = OrganizationSummary(
      id: 9,
      slug: slug,
      name: name,
      picture: picture ?? '',
      role: 'owner',
      projectCount: 0,
    );
    contextData = OrganizationContextData(
      personal: contextData.personal,
      organizations: [...contextData.organizations, organization],
    );
    return organization;
  }
}

OrganizationContextData _fixture() => const OrganizationContextData(
  personal: PersonalWorkspaceSummary(
    id: 1,
    slug: 'dev',
    name: 'Dev',
    picture: '',
    projectCount: 2,
  ),
  organizations: [
    OrganizationSummary(
      id: 7,
      slug: 'acme',
      name: 'Acme',
      picture: '',
      role: 'owner',
      projectCount: 3,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('organization selection is membership-scoped and persisted', () async {
    SharedPreferences.setMockInitialValues({'active_organization_id': 7});
    final provider = OrganizationProvider(
      service: _FakeOrganizationService(_fixture()),
    );

    await provider.load();
    expect(provider.activeOrganizationId, 7);
    expect(provider.workspaceName, 'Acme');

    await provider.select(999);
    expect(provider.activeOrganizationId, 7);

    await provider.select(null);
    expect(provider.activeOrganizationId, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('active_organization_id'), isFalse);
  });

  test('created organization becomes the active workspace', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = OrganizationProvider(
      service: _FakeOrganizationService(_fixture()),
    );
    await provider.load();

    await provider.create(name: 'New Team', slug: 'new-team');

    expect(provider.activeOrganizationId, 9);
    expect(provider.activeOrganization?.slug, 'new-team');
  });
}
