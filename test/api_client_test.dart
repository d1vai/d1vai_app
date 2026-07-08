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
}
