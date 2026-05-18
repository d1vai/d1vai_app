import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class OAuthCallbackService {
  static const String _channelBase = 'ai.d1v.d1vaiapp/oauth_callback';
  static const EventChannel _eventChannel = EventChannel(_channelBase);
  static const MethodChannel _methodChannel = MethodChannel(
    '${_channelBase}_control',
  );

  Future<String> authenticateWithExternalBrowser({
    required Uri url,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    await _clearPendingCallback();

    final completer = Completer<String>();
    late final StreamSubscription<dynamic> subscription;
    subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final callbackUrl = (event as String?)?.trim() ?? '';
        if (!_isLoginCallback(callbackUrl) || completer.isCompleted) return;
        completer.complete(callbackUrl);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (completer.isCompleted) return;
        completer.completeError(error, stackTrace);
      },
    );

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open the OAuth sign-in page');
      }

      final pendingCallback = await _takePendingCallback();
      if (pendingCallback != null &&
          pendingCallback.isNotEmpty &&
          !completer.isCompleted &&
          _isLoginCallback(pendingCallback)) {
        completer.complete(pendingCallback);
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('OAuth callback timed out'),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _clearPendingCallback() {
    return _methodChannel.invokeMethod<void>('clearPending');
  }

  Future<String?> _takePendingCallback() {
    return _methodChannel.invokeMethod<String>('takePending');
  }

  bool _isLoginCallback(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'd1vai') {
      return false;
    }
    return uri.host == 'login' ||
        uri.path.replaceAll(RegExp(r'/+$'), '') == '/login';
  }
}
