import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MacosOpenService extends ChangeNotifier {
  MacosOpenService._();

  static final MacosOpenService instance = MacosOpenService._();

  static const MethodChannel _channel = MethodChannel('ai.d1v.d1vai/open');

  final List<String> _pendingImportPaths = <String>[];

  String? get pendingImportPath =>
      _pendingImportPaths.isEmpty ? null : _pendingImportPaths.first;

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openImportPath') return;
      final path = (call.arguments ?? '').toString().trim();
      debugPrint('[d1vai-drop] flutter openImportPath raw=${call.arguments}');
      enqueueImportPath(path);
    });
  }

  void enqueueImportPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    _pendingImportPaths.add(trimmed);
    debugPrint(
      '[d1vai-drop] flutter queued import path=$trimmed queue=${_pendingImportPaths.length}',
    );
    notifyListeners();
  }

  String? consumePendingImportPath() {
    if (_pendingImportPaths.isEmpty) return null;
    final value = _pendingImportPaths.first;
    _pendingImportPaths.removeAt(0);
    debugPrint(
      '[d1vai-drop] flutter consumed import path=$value remaining=${_pendingImportPaths.length}',
    );
    return value;
  }
}
