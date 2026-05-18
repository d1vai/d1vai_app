import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_monaco/src/platform/platform_webview.dart';

typedef ScriptMatcher = bool Function(String script);
typedef ScriptResultResolver = Object? Function(String script);

class FakeMonacoPlatformWebViewController implements PlatformWebViewController {
  FakeMonacoPlatformWebViewController({Widget? widget})
    : _widget = widget ?? const SizedBox.shrink();

  final List<String> executed = [];
  final Map<String, void Function(String)> _channels = {};
  final Widget _widget;

  bool initialized = false;
  bool jsEnabled = false;
  bool disposed = false;
  bool interactionEnabled = true;

  final Map<String, Queue<Object?>> _resultsQueue = {};
  ScriptResultResolver? resultResolver;
  final List<ScriptMatcher> _throwMatchers = [];

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> enableJavaScript() async {
    jsEnabled = true;
  }

  @override
  Future<void> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  ) async {
    _channels[name] = onMessage;
  }

  @override
  Future<void> removeJavaScriptChannel(String name) async {
    _channels.remove(name);
  }

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) async {
    executed.add('LOAD_FILE:$customCss:$allowCdnFonts');
  }

  @override
  Future<void> setBackgroundColor(Color color) async {
    executed.add('SET_BACKGROUND_COLOR:$color');
  }

  @override
  Future<void> setInteractionEnabled(bool enabled) async {
    interactionEnabled = enabled;
    executed.add('SET_INTERACTION:$enabled');
  }

  @override
  Future<Object?> runJavaScript(String script) async {
    if (_shouldThrow(script)) {
      throw StateError('Fake runJavaScript error for: $script');
    }
    executed.add(script);
    return null;
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    if (_shouldThrow(script)) {
      throw StateError('Fake runJavaScriptReturningResult error for: $script');
    }
    executed.add(script);
    return _getResult(script);
  }

  @override
  Widget get widget => _widget;

  @override
  void dispose() {
    disposed = true;
  }

  void enqueueResult(String script, Object? result) {
    _resultsQueue.putIfAbsent(script, () => Queue<Object?>()).add(result);
  }

  void throwOnContains(String substring) {
    _throwMatchers.add((script) => script.contains(substring));
  }

  bool hasChannel(String name) => _channels.containsKey(name);

  void emitToChannel(String name, String message) {
    final handler = _channels[name];
    if (handler == null) {
      throw StateError('No channel registered for $name');
    }
    handler(message);
  }

  Object? _getResult(String script) {
    final queue = _resultsQueue[script];
    if (queue != null && queue.isNotEmpty) {
      return queue.removeFirst();
    }
    if (resultResolver != null) {
      return resultResolver!(script);
    }
    return null;
  }

  bool _shouldThrow(String script) {
    for (final matcher in _throwMatchers) {
      if (matcher(script)) return true;
    }
    return false;
  }
}
