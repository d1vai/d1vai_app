import 'dart:convert';

import '../../../models/message.dart';

String normalizeToolStatusValue(String? value, {String fallback = 'done'}) {
  final raw = value?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return fallback;
  if (raw == 'processing' ||
      raw == 'running' ||
      raw == 'pending' ||
      raw == 'queued' ||
      raw == 'in_progress' ||
      raw == 'in-progress') {
    return 'processing';
  }
  if (raw == 'error' || raw == 'failed' || raw == 'failure') {
    return 'error';
  }
  if (raw == 'warning' || raw == 'warn') return 'warning';
  if (raw == 'done' ||
      raw == 'completed' ||
      raw == 'complete' ||
      raw == 'success' ||
      raw == 'succeeded' ||
      raw == 'ok') {
    return 'done';
  }
  return raw;
}

String normalizeTodoStatus(String? value) {
  final raw = value?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return 'pending';
  if (raw == 'done' ||
      raw == 'completed' ||
      raw == 'complete' ||
      raw == 'success' ||
      raw == 'succeeded' ||
      raw == 'ok') {
    return 'done';
  }
  if (raw == 'in_progress' ||
      raw == 'in-progress' ||
      raw == 'running' ||
      raw == 'active' ||
      raw == 'current') {
    return 'in_progress';
  }
  return 'pending';
}

({
  int completedCount,
  String progressText,
  String state,
  String taskText,
  List<({String content, String status})> todos,
})?
inferTodoWriteState(dynamic input) {
  if (input is! Map) return null;
  final todos = input['todos'];
  if (todos is! List || todos.isEmpty) return null;

  final items = <({String content, String status})>[];
  for (final todo in todos) {
    if (todo is Map) {
      items.add((
        content: todo['content']?.toString().trim() ?? '',
        status: normalizeTodoStatus(todo['status']?.toString()),
      ));
    } else {
      items.add((content: '', status: 'pending'));
    }
  }

  final total = items.length;
  var activeIndex = -1;
  for (var i = 0; i < items.length; i++) {
    if (items[i].status == 'in_progress') {
      activeIndex = i;
      break;
    }
  }

  if (activeIndex >= 0) {
    final inferred = <({String content, String status})>[];
    for (var i = 0; i < items.length; i++) {
      final status = i < activeIndex
          ? 'done'
          : i == activeIndex
          ? 'in_progress'
          : items[i].status == 'done'
          ? 'done'
          : 'pending';
      inferred.add((content: items[i].content, status: status));
    }
    return (
      completedCount: activeIndex + 1,
      progressText: '${activeIndex + 1}/$total',
      state: 'in_progress',
      taskText: truncateText(items[activeIndex].content, maxLen: 80),
      todos: inferred,
    );
  }

  final completedCount = items.where((todo) => todo.status == 'done').length;
  final state = switch (completedCount) {
    0 => 'pending',
    _ when completedCount >= total => 'done_all',
    _ => 'partial',
  };
  return (
    completedCount: completedCount,
    progressText: '$completedCount/$total',
    state: state,
    taskText: '',
    todos: items,
  );
}

/// Normalizes tool status from explicit field or input map.
/// Matches d1vai web behavior: status/state/level in input are treated as status hints.
String coerceToolStatus(String? status, dynamic input) {
  final normalized = normalizeToolStatusValue(status, fallback: '');
  if (normalized.isNotEmpty) return normalized;
  if (input is Map) {
    final v = input['status'] ?? input['state'] ?? input['level'];
    final inferred = normalizeToolStatusValue(v?.toString(), fallback: '');
    if (inferred.isNotEmpty) return inferred;

    final todoState = inferTodoWriteState(input);
    if (todoState != null) {
      return todoState.state == 'done_all' ? 'done' : 'processing';
    }
  }
  return 'done';
}

String truncateText(String input, {int maxLen = 56}) {
  final s = input.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return '';
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 1)}…';
}

String shortenToolFilePath(String input, {int maxSegments = 3}) {
  final path = input.trim();
  if (path.isEmpty) return '';
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.length <= maxSegments) return path;
  return '…/${segs.sublist(segs.length - maxSegments).join('/')}';
}

({String progressText, String state, String taskText})? todoWriteHeader(
  dynamic input,
) {
  final state = inferTodoWriteState(input);
  if (state == null) return null;
  return (
    progressText: state.progressText,
    state: state.state,
    taskText: state.taskText,
  );
}

String toolSummary(String toolName, dynamic input) {
  final name = toolName.trim();
  try {
    switch (name) {
      case 'Read':
      case 'read':
        {
          final p = (input is Map
              ? (input['file_path']?.toString() ?? '')
              : '');
          return shortenToolFilePath(p).isNotEmpty
              ? shortenToolFilePath(p)
              : '(unknown)';
        }
      case 'Write':
      case 'write':
        {
          final p = (input is Map
              ? (input['file_path']?.toString() ?? '')
              : '');
          return 'Write File ${p.isNotEmpty ? shortenToolFilePath(p, maxSegments: 4) : '(unknown)'}';
        }
      case 'Edit':
      case 'edit':
        {
          final p = (input is Map
              ? (input['file_path']?.toString() ?? '')
              : '');
          return shortenToolFilePath(p).isNotEmpty
              ? shortenToolFilePath(p)
              : '(unknown)';
        }
      case 'MultiEdit':
      case 'multi_edit':
      case 'multiedit':
        {
          final p = (input is Map
              ? (input['file_path']?.toString() ?? '')
              : '');
          final edits = (input is Map ? input['edits'] : null);
          final n = edits is List ? edits.length : null;
          final base = p.isNotEmpty
              ? shortenToolFilePath(p, maxSegments: 4)
              : '(unknown)';
          return 'MultiEdit $base${n != null ? ' ($n)' : ''}';
        }
      case 'Bash':
      case 'bash':
        {
          final cmd = (input is Map
              ? (input['command']?.toString() ?? '')
              : '');
          return cmd.isNotEmpty
              ? 'Run ${truncateText(cmd, maxLen: 64)}'
              : 'Run command';
        }
      case 'Glob':
      case 'glob':
        {
          final pat = (input is Map
              ? (input['pattern']?.toString() ?? '')
              : '');
          return pat.isNotEmpty ? 'Glob ${truncateText(pat)}' : 'Glob';
        }
      case 'Grep':
      case 'grep':
        {
          final pat = (input is Map
              ? (input['pattern']?.toString() ?? '')
              : '');
          return pat.isNotEmpty ? 'Grep ${truncateText(pat)}' : 'Grep';
        }
      case 'WebSearch':
      case 'websearch':
      case 'web_search':
        {
          final q = (input is Map ? (input['query']?.toString() ?? '') : '');
          return q.isNotEmpty ? 'WebSearch ${truncateText(q)}' : 'WebSearch';
        }
      case 'WebFetch':
      case 'webfetch':
      case 'web_fetch':
        {
          final url = (input is Map ? (input['url']?.toString() ?? '') : '');
          return url.isNotEmpty ? 'WebFetch ${truncateText(url)}' : 'WebFetch';
        }
      case 'TodoWrite':
      case 'todowrite':
      case 'todo_write':
        {
          final header = todoWriteHeader(input);
          if (header == null) return 'TodoWrite';
          if (header.state == 'done_all') {
            return 'TodoWrite · ${header.progressText} · done';
          }
          if (header.state == 'pending') {
            return 'TodoWrite · ${header.progressText} · pending';
          }
          if (header.state == 'partial') {
            return 'TodoWrite · ${header.progressText} · partial';
          }
          return 'TodoWrite · ${header.progressText} · In Progress${header.taskText.isNotEmpty ? ' · ${header.taskText}' : ''}';
        }
      case 'Task':
      case 'task':
        {
          final desc = (input is Map
              ? [
                  input['description']?.toString() ?? '',
                  input['goal']?.toString() ?? '',
                  input['title']?.toString() ?? '',
                  input['prompt']?.toString() ?? '',
                ].firstWhere(
                  (value) => value.trim().isNotEmpty,
                  orElse: () => '',
                )
              : '');
          final t = (input is Map
              ? (input['task_type']?.toString() ?? '')
              : '');
          final s = [
            'Task',
            if (t.isNotEmpty) t,
            if (desc.isNotEmpty) truncateText(desc, maxLen: 56),
          ].join(' · ');
          return s;
        }
      default:
        return name.isNotEmpty ? 'Tool · $name' : 'Tool';
    }
  } catch (_) {
    return name.isNotEmpty ? 'Tool · $name' : 'Tool';
  }
}

String prettyJson(dynamic input) {
  try {
    if (input == null) return 'null';
    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        final decoded = jsonDecode(trimmed);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
      return input;
    }
    return const JsonEncoder.withIndent('  ').convert(input);
  } catch (_) {
    return input?.toString() ?? '';
  }
}

bool toolMessageHasProcessing(ToolMessageContent c) {
  return coerceToolStatus(c.status, c.input) == 'processing';
}
