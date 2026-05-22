import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

class MacosRecentProjectEntry {
  final String id;
  final String name;
  final DateTime seenAt;

  const MacosRecentProjectEntry({
    required this.id,
    required this.name,
    required this.seenAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'seen_at': seenAt.toIso8601String(),
  };

  factory MacosRecentProjectEntry.fromJson(Map<String, dynamic> json) {
    return MacosRecentProjectEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      seenAt:
          DateTime.tryParse((json['seen_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MacosRecentWorkspaceEntry {
  final String path;
  final String label;
  final DateTime seenAt;

  const MacosRecentWorkspaceEntry({
    required this.path,
    required this.label,
    required this.seenAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'label': label,
    'seen_at': seenAt.toIso8601String(),
  };

  factory MacosRecentWorkspaceEntry.fromJson(Map<String, dynamic> json) {
    return MacosRecentWorkspaceEntry(
      path: (json['path'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      seenAt:
          DateTime.tryParse((json['seen_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MacosMenuController extends ChangeNotifier {
  static const String _prefsRecentProjectsKey = 'macos_recent_projects';
  static const String _prefsRecentWorkspacesKey = 'macos_recent_workspaces';
  static const int _maxRecentProjects = 8;
  static const int _maxRecentWorkspaces = 8;

  List<MacosRecentProjectEntry> _recentProjects =
      const <MacosRecentProjectEntry>[];
  List<MacosRecentWorkspaceEntry> _recentWorkspaces =
      const <MacosRecentWorkspaceEntry>[];
  bool _loaded = false;
  String? _currentProjectId;
  String? _currentProjectName;
  bool _notifyScheduled = false;

  List<MacosRecentProjectEntry> get recentProjects => _recentProjects;
  List<MacosRecentWorkspaceEntry> get recentWorkspaces => _recentWorkspaces;
  bool get loaded => _loaded;
  String? get currentProjectId => _currentProjectId;
  String? get currentProjectName => _currentProjectName;
  bool get hasCurrentProject => (_currentProjectId ?? '').trim().isNotEmpty;

  void _notifyListenersSafely() {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        schedulerPhase != SchedulerPhase.idle &&
        schedulerPhase != SchedulerPhase.postFrameCallbacks;
    if (!shouldDefer) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList(_prefsRecentProjectsKey) ?? const <String>[];
      _recentProjects = raw
          .map((item) {
            try {
              return MacosRecentProjectEntry.fromJson(
                jsonDecode(item) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<MacosRecentProjectEntry>()
          .toList(growable: false);

      final rawWorkspaces =
          prefs.getStringList(_prefsRecentWorkspacesKey) ?? const <String>[];
      _recentWorkspaces = rawWorkspaces
          .map((item) {
            try {
              return MacosRecentWorkspaceEntry.fromJson(
                jsonDecode(item) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<MacosRecentWorkspaceEntry>()
          .toList(growable: false);
    } catch (_) {
      _recentProjects = const <MacosRecentProjectEntry>[];
      _recentWorkspaces = const <MacosRecentWorkspaceEntry>[];
    } finally {
      _loaded = true;
      _notifyListenersSafely();
    }
  }

  Future<void> registerProjectVisit(UserProject project) async {
    final id = project.id.trim();
    if (id.isEmpty) return;
    final name = project.projectName.trim().isEmpty
        ? id
        : project.projectName.trim();
    setCurrentProjectContext(id: id, name: name);
    final entry = MacosRecentProjectEntry(
      id: id,
      name: name,
      seenAt: DateTime.now(),
    );
    final next = <MacosRecentProjectEntry>[
      entry,
      ..._recentProjects.where((item) => item.id != id),
    ].take(_maxRecentProjects).toList(growable: false);
    _recentProjects = next;
    _notifyListenersSafely();
    await _persist();
  }

  Future<void> registerLocalWorkspaceVisit({
    required String path,
    String? label,
  }) async {
    final normalizedPath = _normalizeWorkspacePath(path);
    if (normalizedPath.isEmpty) return;

    final displayLabel = (label ?? '').trim().isNotEmpty
        ? label!.trim()
        : _fallbackWorkspaceLabel(normalizedPath);
    final entry = MacosRecentWorkspaceEntry(
      path: normalizedPath,
      label: displayLabel,
      seenAt: DateTime.now(),
    );

    _recentWorkspaces = <MacosRecentWorkspaceEntry>[
      entry,
      ..._recentWorkspaces.where((item) => item.path != normalizedPath),
    ].take(_maxRecentWorkspaces).toList(growable: false);
    _notifyListenersSafely();
    await _persistRecentWorkspaces();
  }

  void setCurrentProjectContext({required String id, required String name}) {
    final nextId = id.trim();
    final nextName = name.trim().isEmpty ? nextId : name.trim();
    if (nextId.isEmpty) return;
    if (_currentProjectId == nextId && _currentProjectName == nextName) return;
    _currentProjectId = nextId;
    _currentProjectName = nextName;
    _notifyListenersSafely();
  }

  void clearCurrentProjectContext({String? expectedId}) {
    if (expectedId != null &&
        expectedId.trim().isNotEmpty &&
        _currentProjectId != expectedId.trim()) {
      return;
    }
    if (_currentProjectId == null && _currentProjectName == null) return;
    _currentProjectId = null;
    _currentProjectName = null;
    _notifyListenersSafely();
  }

  Future<void> clearRecentProjects() async {
    _recentProjects = const <MacosRecentProjectEntry>[];
    _notifyListenersSafely();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsRecentProjectsKey);
    } catch (_) {}
  }

  Future<void> clearRecentWorkspaces() async {
    _recentWorkspaces = const <MacosRecentWorkspaceEntry>[];
    _notifyListenersSafely();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsRecentWorkspacesKey);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsRecentProjectsKey,
        _recentProjects.map((item) => jsonEncode(item.toJson())).toList(),
      );
    } catch (_) {}
  }

  Future<void> _persistRecentWorkspaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsRecentWorkspacesKey,
        _recentWorkspaces.map((item) => jsonEncode(item.toJson())).toList(),
      );
    } catch (_) {}
  }

  String _normalizeWorkspacePath(String path) {
    return path.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  }

  String _fallbackWorkspaceLabel(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    final last = parts.isEmpty ? path : parts.last.trim();
    return last.isEmpty ? path : last;
  }
}
