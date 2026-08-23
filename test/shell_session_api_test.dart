import 'dart:convert';

import 'package:d1vai_app/core/api_client.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> connectionData({String? projectId}) => <String, dynamic>{
  'session_id': 'sh_1',
  'workspace_scope': 'organization:42',
  'project_id': projectId,
  'runtime_provider': 'fabric',
  'node_id': 'node-1',
  'cwd': projectId == null ? '/workspace' : '/workspace/projects/$projectId',
  'transport': 'direct',
  'websocket_url': 'wss://node.d1v.dev/ws/terminal/sh_1',
  'connection_ticket': 'ticket',
  'ticket_expires_at': '2026-08-24T12:00:00Z',
};

Map<String, dynamic> metadataData({String status = 'terminated'}) =>
    <String, dynamic>{
      'session_id': 'sh_1',
      'workspace_scope': 'organization:42',
      'project_id': null,
      'cwd': '/workspace',
      'status': status,
      'exit_code': null,
      'termination_reason': status == 'terminated' ? 'client_request' : null,
    };

http.Response wrapped(Object? data) => http.Response(
  jsonEncode(<String, dynamic>{'code': 0, 'msg': 'success', 'data': data}),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
    });
    await ApiClient.setRuntimeBaseUrlOverride('https://api.test');
  });

  tearDown(() => ApiClient.setRuntimeBaseUrlOverride(null));

  test(
    'creates an organization workspace session with measured size',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/workspace/shell-sessions');
        expect(request.url.queryParameters, {'organization_id': '42'});
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'target': 'workspace',
          'cols': 100,
          'rows': 32,
          'shell': 'auto',
        });
        return wrapped(connectionData());
      });

      final result = await ShellSessionApi(
        apiClient: ApiClient(client: client),
      ).create(organizationId: 42, columns: 100, rows: 32);

      expect(result.workspaceScope, 'organization:42');
      expect(result.projectId, isNull);
    },
  );

  test('creates a project session without a client-provided cwd', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/projects/project%20one/shell-sessions');
      expect(request.url.query, isEmpty);
      expect(jsonDecode(request.body), {
        'target': 'project',
        'cols': 120,
        'rows': 40,
        'shell': 'auto',
      });
      return wrapped(connectionData(projectId: 'project one'));
    });

    final result = await ShellSessionApi(
      apiClient: ApiClient(client: client),
    ).create(projectId: ' project one ', columns: 120, rows: 40);

    expect(result.projectId, 'project one');
    expect(result.cwd, '/workspace/projects/project one');
  });

  test(
    'gets, refreshes, and closes only encoded session identifiers',
    () async {
      final methods = <String>[];
      final paths = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        paths.add(request.url.path);
        if (request.url.path.endsWith('/ticket')) {
          return wrapped(connectionData());
        }
        return wrapped(
          metadataData(
            status: request.method == 'GET' ? 'ready' : 'terminated',
          ),
        );
      });
      final api = ShellSessionApi(apiClient: ApiClient(client: client));

      expect((await api.get('sh one')).status, ShellSessionStatus.ready);
      expect((await api.refreshTicket('sh one')).sessionId, 'sh_1');
      expect((await api.close('sh one')).status, ShellSessionStatus.terminated);

      expect(methods, ['GET', 'POST', 'DELETE']);
      expect(paths, [
        '/api/shell-sessions/sh%20one',
        '/api/shell-sessions/sh%20one/ticket',
        '/api/shell-sessions/sh%20one',
      ]);
    },
  );

  test('rejects empty session identifiers before making a request', () {
    final api = ShellSessionApi(
      apiClient: ApiClient(
        client: MockClient((request) => throw StateError('unexpected request')),
      ),
    );
    expect(() => api.get(' '), throwsFormatException);
  });
}
