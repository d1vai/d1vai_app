class WorkspaceCliResult<T> {
  final bool ok;
  final String code;
  final String message;
  final T? data;

  const WorkspaceCliResult({
    required this.ok,
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson(Object? Function(T value)? encodeData) {
    return {
      'ok': ok,
      'code': code,
      'message': message,
      'data': data == null || encodeData == null ? data : encodeData(data as T),
    };
  }
}
