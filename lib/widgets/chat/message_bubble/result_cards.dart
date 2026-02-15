import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../markdown_text.dart';
import '../tools/tool_utils.dart';
import 'message_card_base.dart';

class ChatResultCard extends StatelessWidget {
  final dynamic payload;

  const ChatResultCard({super.key, required this.payload});

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : null;

  Map<String, dynamic> _unwrap(dynamic v) {
    final root = _map(v) ?? const <String, dynamic>{};
    final inner = _map(root['payload']);
    if (inner != null &&
        (inner.containsKey('result') ||
            inner.containsKey('subtype') ||
            inner.containsKey('usage') ||
            inner.containsKey('duration_ms') ||
            inner.containsKey('num_turns'))) {
      return inner;
    }
    return root;
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 1000).round()}k';
    if (n >= 1000) {
      final v = (n / 1000);
      final s = v.toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = chatSuccessTint(theme);
    final p = _unwrap(payload);
    final subtype = (p['subtype']?.toString() ?? 'unknown').toLowerCase();
    final isError = p['is_error'] == true || subtype == 'error';
    final resultText = p['result']?.toString() ?? '';
    final numTurns = _int(p['num_turns']) ?? 0;
    final durationMs = _int(p['duration_ms']) ?? 0;
    final durationSec = durationMs > 0 ? (durationMs / 1000).round() : 0;

    final usage =
        _map(p['usage']) ??
        _map(_map(p['message'])?['usage']) ??
        const <String, dynamic>{};
    final inputTokens =
        _int(p['input_tokens']) ??
        _int(usage['input_tokens']) ??
        _int(usage['prompt_tokens']);
    final outputTokens =
        _int(p['output_tokens']) ??
        _int(usage['output_tokens']) ??
        _int(usage['completion_tokens']);

    final Color tint = isError
        ? theme.colorScheme.error
        : subtype == 'success'
        ? successTint
        : theme.colorScheme.primary;

    final bg = tint.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10,
    );
    final title = isError
        ? 'Error'
        : (subtype == 'success' ? 'Success' : 'Result');
    final icon = isError
        ? Icons.cancel
        : (subtype == 'success'
              ? Icons.check_circle
              : Icons.smart_toy_outlined);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(icon, size: 14, color: tint),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (inputTokens != null || outputTokens != null)
                  Text(
                    '${inputTokens != null ? '↑${_formatCount(inputTokens)}' : ''}${inputTokens != null && outputTokens != null ? '  ' : ''}${outputTokens != null ? '↓${_formatCount(outputTokens)}' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (numTurns > 0) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$numTurns turns',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (durationSec > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${durationSec}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 1,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 224),
              child: SingleChildScrollView(
                child: MarkdownText(
                  text: resultText.isNotEmpty ? resultText : '🎉 Done',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatRawCard extends StatelessWidget {
  final dynamic payload;

  const ChatRawCard({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = prettyJson(payload);
    String? typeLabel;
    if (payload is Map) {
      final t = (payload as Map)['type'];
      if (t != null && t.toString().trim().isNotEmpty) {
        typeLabel = t.toString().trim();
      }
    }

    return ChatMessageCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
            icon: Icons.data_object,
            iconColor: theme.colorScheme.onSurfaceVariant,
            title: typeLabel != null ? 'Raw · $typeLabel' : 'Raw',
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied raw payload'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            copyLabel: 'Copy raw payload',
          ),
          const SizedBox(height: 8),
          ChatExpandableSelectableBlock(
            text: text,
            collapsedLines: 10,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.25,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
