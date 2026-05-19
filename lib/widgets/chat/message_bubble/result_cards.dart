import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../desktop_selection_shell.dart';
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

    final tint = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final title = isError ? 'Error' : 'Result';
    final icon = isError ? Icons.cancel : Icons.notes_rounded;

    return ChatMessageCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.26 : 0.32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(icon: icon, iconColor: tint, title: title),
          if (inputTokens != null ||
              outputTokens != null ||
              numTurns > 0 ||
              durationSec > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (inputTokens != null || outputTokens != null)
                  _MetaChip(
                    label:
                        '${inputTokens != null ? '↑${_formatCount(inputTokens)}' : ''}${inputTokens != null && outputTokens != null ? '  ' : ''}${outputTokens != null ? '↓${_formatCount(outputTokens)}' : ''}',
                  ),
                if (numTurns > 0) _MetaChip(label: '$numTurns turns'),
                if (durationSec > 0) _MetaChip(label: '${durationSec}s'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 224),
            child: SingleChildScrollView(
              child: _PlainSelectableBody(
                text: resultText.isNotEmpty ? resultText : 'Done',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
                  fontSize: 13,
                  height: 1.34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlainSelectableBody extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _PlainSelectableBody({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final content = SelectableText(text, style: style);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return DesktopSelectionShell(child: content);
    }
    return Text(text, style: style);
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
          ),
          const SizedBox(height: 8),
          _SelectableBody(
            text: text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11.6,
              height: 1.28,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableBody extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _SelectableBody({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final body = MarkdownText(text: text, style: style);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return DesktopSelectionShell(child: body);
    }
    return body;
  }
}
