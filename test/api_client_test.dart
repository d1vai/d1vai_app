import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/core/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'postWithQuery keeps the request body empty when body is null',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/user/verify-code');
        expect(request.url.queryParameters['email'], 'test@example.com');
        expect(request.url.queryParameters['locale'], 'zh-CN');
        expect(request.headers['content-type'], 'application/json');
        expect(request.bodyBytes, isEmpty);

        return http.Response(
          '{"code":0,"msg":"success","data":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: client);

      await apiClient.postWithQuery<void>('/api/user/verify-code', {
        'email': 'test@example.com',
        'locale': 'zh-CN',
      }, null);
    },
  );

  test(
    'authenticated request logs never include a token fingerprint',
    () async {
      const token = 'e2e-secret-token-with-distinctive-tail-93KQ7Z';
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_token', token);
      addTearDown(() => preferences.remove('auth_token'));
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);

      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          '{"code":0,"msg":"success","data":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await ApiClient(client: client).get<Map<String, dynamic>>('/api/private');

      final output = messages.join('\n');
      expect(output, contains('Auth: present'));
      expect(output, isNot(contains(token)));
      expect(output, isNot(contains('93KQ7Z')));
      expect(output, isNot(contains('suffix=')));
      expect(output, isNot(contains('len=')));
    },
  );
}
