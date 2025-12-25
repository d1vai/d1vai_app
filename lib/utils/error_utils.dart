String humanizeError(Object error) {
  var message = error.toString().trim();

  // Common Dart exception wrappers.
  if (message.startsWith('Exception: ')) {
    message = message.substring('Exception: '.length).trim();
  }
  if (message.startsWith('HttpException: ')) {
    message = message.substring('HttpException: '.length).trim();
  }

  // Network-ish failures (http package wraps SocketException).
  final lower = message.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return '网络连接失败，请检查网络后重试';
  }

  if (lower.contains('timed out') || lower.contains('timeout')) {
    return '请求超时，请稍后重试';
  }

  if (lower.contains('http error: 401') || lower.contains('statuscode: 401')) {
    return '登录已过期，请重新登录';
  }

  // Keep backend message when available, otherwise return trimmed raw.
  return message.isEmpty ? '请求失败，请稍后重试' : message;
}

bool isAuthExpiredText(String message) {
  final m = message.trim().toLowerCase();
  return m.contains('登录已过期') ||
      m.contains('unauthorized') ||
      m.contains('http error: 401') ||
      m.contains('statuscode: 401') ||
      m.contains(' 401 ');
}
