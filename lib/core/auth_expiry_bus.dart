import 'dart:async';

enum AuthExpiryReason { unauthorized }

class AuthExpiredEvent {
  final AuthExpiryReason reason;
  final DateTime at;
  final String? endpoint;

  AuthExpiredEvent({
    required this.reason,
    required this.at,
    this.endpoint,
  });
}

class AuthExpiredException implements Exception {
  final String message;

  AuthExpiredException([this.message = 'Session expired']);

  @override
  String toString() => 'Exception: HTTP Error: 401 $message';
}

class AuthExpiryBus {
  static final StreamController<AuthExpiredEvent> _controller =
      StreamController<AuthExpiredEvent>.broadcast();

  static bool _triggered = false;

  static Stream<AuthExpiredEvent> get stream => _controller.stream;
  static bool get isTriggered => _triggered;

  static void trigger({String? endpoint}) {
    if (_triggered) return;
    _triggered = true;
    _controller.add(
      AuthExpiredEvent(
        reason: AuthExpiryReason.unauthorized,
        at: DateTime.now(),
        endpoint: endpoint,
      ),
    );
  }

  static void reset() {
    _triggered = false;
  }
}

