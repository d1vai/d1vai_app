import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/core/api_client.dart';
import 'package:d1vai_app/models/project.dart';
import 'package:d1vai_app/services/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'workspace status cache and query remain isolated by owner scope',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        final organizationId = request.url.queryParameters['organization_id'];
        return http.Response(
          jsonEncode({
            'code': 0,
            'msg': 'success',
            'data': {
              'status': 'ACTIVE',
              'ip': organizationId == null ? '10.0.0.1' : '10.0.0.7',
              'port': 8080,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(client: client);
      final personal = WorkspaceService(apiClient: api);
      final organization = WorkspaceService(apiClient: api, organizationId: 7);

      final personalStatus = await personal.getWorkspaceStatus();
      final organizationStatus = await organization.getWorkspaceStatus();

      expect(personalStatus.ip, '10.0.0.1');
      expect(organizationStatus.ip, '10.0.0.7');
      expect(requests, hasLength(2));
      expect(requests.first.queryParameters['organization_id'], isNull);
      expect(requests.last.queryParameters['organization_id'], '7');
    },
  );

  test('workspace discover sends organization scope as a query', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'msg': 'success',
          'data': {'status': 'ACTIVE', 'ip': '10.0.0.7', 'port': 8080},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await WorkspaceService(
      apiClient: ApiClient(client: client),
      organizationId: 7,
    ).discoverWorkspace();

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/api/workspace/discover');
    expect(captured?.url.queryParameters['organization_id'], '7');
    expect(captured?.body, '{}');
  });

  test('workspace status and discover preserve project scope safely', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'code': 0,
          'msg': 'success',
          'data': {'status': 'ACTIVE', 'ip': '10.0.0.9', 'port': 8080},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = WorkspaceService(
      apiClient: ApiClient(client: client),
      organizationId: 7,
      projectId: ' project one ',
    );

    await service.getWorkspaceStatus();
    await service.discoverWorkspace();

    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.url.queryParameters['organization_id'], '7');
      expect(request.url.queryParameters['project_id'], 'project one');
    }
    expect(requests.last.url.path, '/api/workspace/discover');
    expect(requests.last.body, '{}');
  });

  test('changing the project invalidates cached workspace readiness', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      return http.Response(
        jsonEncode({
          'code': 0,
          'msg': 'success',
          'data': {'status': 'ACTIVE', 'ip': '10.0.0.$requests', 'port': 8080},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = WorkspaceService(apiClient: ApiClient(client: client));

    expect((await service.getWorkspaceStatus()).ip, '10.0.0.1');
    expect((await service.getWorkspaceStatus()).ip, '10.0.0.1');
    service.setProject('project-2');
    expect((await service.getWorkspaceStatus()).ip, '10.0.0.2');
    expect(requests, 2);
  });

  test('project model preserves organization workspace scope', () {
    final project = UserProject.fromJson({
      'id': 'project-1',
      'project_name': 'Organization project',
      'organization_id': 7,
    });

    expect(project.organizationId, 7);
    expect(project.toJson()['organization_id'], 7);
  });
}
