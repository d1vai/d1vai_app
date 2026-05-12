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

class MacosMenuController extends ChangeNotifier {
  static const String _prefsRecentProjectsKey = 'macos_recent_projects';
  static const int _maxRecentProjects = 8;

  List<MacosRecentProjectEntry> _recentProjects =
      const <MacosRecentProjectEntry>[];
  bool _loaded = false;
  String? _currentProjectId;
  String? _currentProjectName;
  bool _notifyScheduled = false;

  List<MacosRecentProjectEntry> get recentProjects => _recentProjects;
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
    } catch (_) {
      _recentProjects = const <MacosRecentProjectEntry>[];
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

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsRecentProjectsKey,
        _recentProjects.map((item) => jsonEncode(item.toJson())).toList(),
      );
    } catch (_) {}
  }
}
