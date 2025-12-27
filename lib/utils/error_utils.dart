import '../core/locale_bus.dart';
import '../l10n/app_localizations.dart';

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
  final loc = AppLocalizations(LocaleBus.locale);

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return loc.translate('error_network');
  }

  if (lower.contains('timed out') || lower.contains('timeout')) {
    return loc.translate('error_timeout');
  }

  if (lower.contains('http error: 401') || lower.contains('statuscode: 401')) {
    return loc.translate('session_expired_message');
  }

  if (lower.contains('unauthenticated') || lower.contains('please login')) {
    return loc.translate('login_first');
  }

  // Keep backend message when available, otherwise return trimmed raw.
  return message.isEmpty ? loc.translate('error_request_failed') : message;
}

bool isAuthExpiredText(String message) {
  final m = message.trim().toLowerCase();
  return m.contains('unauthorized') ||
      m.contains('http error: 401') ||
      m.contains('statuscode: 401') ||
      m.contains('session expired') ||
      m.contains('bad credentials') ||
      m.contains(' 401 ');
}
