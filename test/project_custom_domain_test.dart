import 'package:d1vai_app/models/project_custom_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the custom-domain API response including DNS records', () {
    final result = ProjectCustomDomainsResponse.fromJson({
      'platform_domain': 'project.d1v.xyz',
      'domains': [
        {
          'id': 7,
          'domain': 'app.example.com',
          'status': 'pending_dns',
          'is_primary': false,
          'verification': [
            {
              'type': 'TXT',
              'domain': '_vercel.example.com',
              'value': 'vc-domain-verify=app.example.com,token',
            },
            {
              'type': 'CNAME',
              'domain': 'app.example.com',
              'value': 'unique-project.vercel-dns-016.com',
              'purpose': 'routing',
            },
          ],
        },
      ],
    });

    expect(result.platformDomain, 'project.d1v.xyz');
    expect(result.domains, hasLength(1));
    expect(result.domains.single.isPendingDns, isTrue);
    expect(result.domains.single.isVerified, isFalse);
    expect(result.domains.single.verification, hasLength(2));
    expect(result.domains.single.verification.last.purpose, 'routing');
  });
}
