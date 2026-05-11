import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MacosOpenService extends ChangeNotifier {
  MacosOpenService._();

  static final MacosOpenService instance = MacosOpenService._();

  static const MethodChannel _channel = MethodChannel('ai.d1v.d1vai/open');

  String? _pendingDirectoryPath;

  String? get pendingDirectoryPath => _pendingDirectoryPath;

  Future<void> initialize({VoidCallback? onDirectoryOpened}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openDirectory') return;
      final path = (call.arguments ?? '').toString().trim();
      if (path.isEmpty) return;
      _pendingDirectoryPath = path;
      notifyListeners();
      onDirectoryOpened?.call();
    });
  }

  String? consumePendingDirectoryPath() {
    final value = _pendingDirectoryPath;
    _pendingDirectoryPath = null;
    return value;
  }
}
