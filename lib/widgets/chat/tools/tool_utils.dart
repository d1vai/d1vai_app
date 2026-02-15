import 'dart:convert';

import '../../../models/message.dart';

/// Normalizes tool status from explicit field or input map.
/// Matches d1vai web behavior: status/state/level in input are treated as status hints.
String coerceToolStatus(String? status, dynamic input) {
  final raw = (status ?? '').trim();
  if (raw.isNotEmpty) return raw.toLowerCase();
  if (input is Map) {
    final v = input['status'] ?? input['state'] ?? input['level'];
    final s = v?.toString().toLowerCase().trim() ?? '';
    if (s == 'processing' || s == 'running' || s == 'pending') {
      return 'processing';
    }
    if (s == 'error' || s == 'failed' || s == 'failure') return 'error';
    if (s == 'warning' || s == 'warn') return 'warning';
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
  if (input is! Map) return null;
  final todos = input['todos'];
  if (todos is! List) return null;
  final total = todos.length;
  if (total == 0) return null;

  var inProgressIdx = -1;
  for (var i = 0; i < todos.length; i++) {
    final t = todos[i];
    if (t is Map && t['status']?.toString() == 'in_progress') {
      inProgressIdx = i;
      break;
    }
  }

  if (inProgressIdx >= 0) {
    final taskText = truncateText(
      (todos[inProgressIdx] is Map
                  ? (todos[inProgressIdx] as Map)['content']
                  : '')
              ?.toString() ??
          '',
      maxLen: 80,
    );
    return (
      progressText: '${inProgressIdx + 1}/$total',
      state: 'in_progress',
      taskText: taskText,
    );
  }

  return (progressText: '$total/$total', state: 'done_all', taskText: '');
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
          return 'TodoWrite · ${header.progressText} · In Progress${header.taskText.isNotEmpty ? ' · ${header.taskText}' : ''}';
        }
      case 'Task':
      case 'task':
        {
          final desc = (input is Map
              ? (input['description']?.toString() ?? '')
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
