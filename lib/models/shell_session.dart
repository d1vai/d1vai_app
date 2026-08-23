enum ShellSessionTransport { direct, relay }

class ShellConnection {
  final String sessionId;
  final String workspaceScope;
  final String? projectId;
  final String runtimeProvider;
  final String nodeId;
  final String cwd;
  final ShellSessionTransport transport;
  final Uri websocketUri;
  final String connectionTicket;
  final DateTime ticketExpiresAt;

  const ShellConnection({
    required this.sessionId,
    required this.workspaceScope,
    required this.projectId,
    required this.runtimeProvider,
    required this.nodeId,
    required this.cwd,
    required this.transport,
    required this.websocketUri,
    required this.connectionTicket,
    required this.ticketExpiresAt,
  });

  factory ShellConnection.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('shell_connection_$key');
      }
      return value.trim();
    }

    final rawTransport = requiredString('transport');
    final transport = switch (rawTransport) {
      'direct' => ShellSessionTransport.direct,
      'relay' => ShellSessionTransport.relay,
      _ => throw const FormatException('shell_connection_transport'),
    };
    final rawProjectId = json['project_id'];
    if (rawProjectId != null && rawProjectId is! String) {
      throw const FormatException('shell_connection_project_id');
    }
    final projectId = (rawProjectId as String?)?.trim();
    final websocketUri = Uri.tryParse(requiredString('websocket_url'));
    if (websocketUri == null || !websocketUri.hasAuthority) {
      throw const FormatException('shell_connection_websocket_url');
    }
    final expiresAt = DateTime.tryParse(requiredString('ticket_expires_at'));
    if (expiresAt == null) {
      throw const FormatException('shell_connection_ticket_expires_at');
    }

    return ShellConnection(
      sessionId: requiredString('session_id'),
      workspaceScope: requiredString('workspace_scope'),
      projectId: projectId == null || projectId.isEmpty ? null : projectId,
      runtimeProvider: requiredString('runtime_provider'),
      nodeId: requiredString('node_id'),
      cwd: requiredString('cwd'),
      transport: transport,
      websocketUri: websocketUri,
      connectionTicket: requiredString('connection_ticket'),
      ticketExpiresAt: expiresAt.toUtc(),
    );
  }
}

enum ShellSessionStatus {
  creating,
  ready,
  detached,
  exited,
  failed,
  terminated,
}

class ShellSessionMetadata {
  final String sessionId;
  final String workspaceScope;
  final String? projectId;
  final String cwd;
  final ShellSessionStatus status;
  final int? exitCode;
  final String? terminationReason;

  const ShellSessionMetadata({
    required this.sessionId,
    required this.workspaceScope,
    required this.projectId,
    required this.cwd,
    required this.status,
    required this.exitCode,
    required this.terminationReason,
  });

  factory ShellSessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString();
    final status = ShellSessionStatus.values.where(
      (candidate) => candidate.name == rawStatus,
    );
    if (status.isEmpty) {
      throw const FormatException('shell_session_status');
    }
    final exitCode = json['exit_code'];
    if (exitCode != null && exitCode is! num) {
      throw const FormatException('shell_session_exit_code');
    }
    return ShellSessionMetadata(
      sessionId: _requiredMetadataString(json, 'session_id'),
      workspaceScope: _requiredMetadataString(json, 'workspace_scope'),
      projectId: json['project_id']?.toString(),
      cwd: _requiredMetadataString(json, 'cwd'),
      status: status.single,
      exitCode: (exitCode as num?)?.toInt(),
      terminationReason: json['termination_reason']?.toString(),
    );
  }
}

String _requiredMetadataString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('shell_session_$key');
  }
  return value.trim();
}
