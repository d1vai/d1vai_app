import '../core/api_client.dart';
import '../models/shell_session.dart';

class ShellSessionApi {
  final ApiClient _apiClient;

  ShellSessionApi({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    final normalizedProjectId = projectId?.trim() ?? '';
    final endpoint = normalizedProjectId.isEmpty
        ? '/api/workspace/shell-sessions'
        : '/api/projects/${Uri.encodeComponent(normalizedProjectId)}/shell-sessions';
    final body = <String, dynamic>{
      'target': normalizedProjectId.isEmpty ? 'workspace' : 'project',
      'cols': columns,
      'rows': rows,
      'shell': 'auto',
    };
    final data = normalizedProjectId.isEmpty && organizationId != null
        ? await _apiClient.postWithQuery<Map<String, dynamic>>(
            endpoint,
            <String, String>{'organization_id': organizationId.toString()},
            body,
            retries: 0,
          )
        : await _apiClient.post<Map<String, dynamic>>(
            endpoint,
            body,
            retries: 0,
          );
    return ShellConnection.fromJson(data);
  }

  Future<ShellSessionMetadata> get(String sessionId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      _sessionEndpoint(sessionId),
      retries: 0,
    );
    return ShellSessionMetadata.fromJson(data);
  }

  Future<ShellConnection> refreshTicket(String sessionId) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      '${_sessionEndpoint(sessionId)}/ticket',
      const <String, dynamic>{},
      retries: 0,
    );
    return ShellConnection.fromJson(data);
  }

  Future<ShellSessionMetadata> close(String sessionId) async {
    final data = await _apiClient.delete<Map<String, dynamic>>(
      _sessionEndpoint(sessionId),
      retries: 0,
    );
    return ShellSessionMetadata.fromJson(data);
  }

  String _sessionEndpoint(String sessionId) {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) {
      throw const FormatException('shell_session_id');
    }
    return '/api/shell-sessions/${Uri.encodeComponent(normalized)}';
  }
}
