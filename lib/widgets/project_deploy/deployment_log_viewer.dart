import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../utils/error_utils.dart';
import '../snackbar_helper.dart';

class DeploymentLogViewer extends StatefulWidget {
  final String log;
  final bool? fromCache;

  const DeploymentLogViewer({
    super.key,
    required this.log,
    required this.fromCache,
  });

  @override
  State<DeploymentLogViewer> createState() => _DeploymentLogViewerState();
}

class _DeploymentLogViewerState extends State<DeploymentLogViewer> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyAll(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() {
        _copied = true;
      });
      _copiedTimer?.cancel();
      _copiedTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          _copied = false;
        });
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Logs copied to clipboard',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Copy failed',
        message: humanizeError(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final parsed = _parseDeploymentLog(widget.log);
    final allLines = parsed.lines;
    const maxRenderLines = 5000;
    final lines = allLines.length > maxRenderLines
        ? allLines.sublist(allLines.length - maxRenderLines)
        : allLines;
    final stderrCount =
        allLines.where((l) => l.stream == _LogStream.stderr).length;

    final background = isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10 * 255)
        : const Color(0xFFE2E8F0);
    final headerBg = isDark ? Colors.white.withValues(alpha: 0.04 * 255) : Colors.white;

    final baseText = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11.5,
      height: 1.45,
      color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF0F172A),
    );

    final muted = isDark ? const Color(0xFF71717A) : const Color(0xFF64748B);
    final unknownText = isDark ? const Color(0xFFD4D4D8) : const Color(0xFF334155);
    final stdoutMarker = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final stderrMarker = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    final stderrText = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFB91C1C);

    final String cacheLabel = widget.fromCache == null
        ? ''
        : (widget.fromCache! ? 'Cached' : 'Live');

    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF0F172A),
    );

    final badgeTextStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 11,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06 * 255),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Build log', style: titleStyle),
                      const SizedBox(width: 10),
                      Text(
                        '${allLines.length} lines',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (allLines.length > maxRenderLines) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(showing last $maxRenderLines)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                      if (stderrCount > 0) ...[
                        Text(
                          ' · $stderrCount stderr',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: stderrText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      if (cacheLabel.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06 * 255)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10 * 255)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            cacheLabel,
                            style: badgeTextStyle?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: parsed.copyText.trim().isEmpty
                      ? null
                      : () => _copyAll(parsed.copyText),
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
                    textStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: borderColor),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06 * 255)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText.rich(
                  TextSpan(
                    style: baseText,
                    children: lines.isEmpty
                        ? [
                            TextSpan(
                              text: widget.log.trim().isEmpty
                                  ? 'No logs available for this deployment.'
                                  : widget.log,
                              style: baseText.copyWith(color: unknownText),
                            ),
                          ]
                        : _buildSpans(
                            lines,
                            baseText: baseText,
                            muted: muted,
                            unknownText: unknownText,
                            stdoutMarker: stdoutMarker,
                            stderrMarker: stderrMarker,
                            stderrText: stderrText,
                          ),
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

List<InlineSpan> _buildSpans(
  List<_DeploymentLogLine> lines, {
  required TextStyle baseText,
  required Color muted,
  required Color unknownText,
  required Color stdoutMarker,
  required Color stderrMarker,
  required Color stderrText,
}) {
  final spans = <InlineSpan>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final time = _formatTime(line.timestampMs);
    if (time.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '$time ',
          style: baseText.copyWith(color: muted),
        ),
      );
    }

    final marker = switch (line.stream) {
      _LogStream.stderr => '›',
      _LogStream.stdout => r'$',
      _LogStream.unknown => '·',
    };

    final markerColor = switch (line.stream) {
      _LogStream.stderr => stderrMarker,
      _LogStream.stdout => stdoutMarker,
      _LogStream.unknown => muted,
    };

    final textColor = switch (line.stream) {
      _LogStream.stderr => stderrText,
      _LogStream.stdout => baseText.color ?? unknownText,
      _LogStream.unknown => unknownText,
    };

    spans.add(
      TextSpan(
        text: '$marker ',
        style: baseText.copyWith(color: markerColor),
      ),
    );

    spans.add(
      TextSpan(
        text: line.text,
        style: baseText.copyWith(color: textColor),
      ),
    );

    if (i != lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }
  return spans;
}

String _formatTime(int? timestampMs) {
  if (timestampMs == null) return '';
  try {
    final d = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  } catch (_) {
    return '';
  }
}

enum _LogStream { stdout, stderr, unknown }

class _DeploymentLogLine {
  final _LogStream stream;
  final int? timestampMs;
  final String text;

  const _DeploymentLogLine({
    required this.stream,
    required this.timestampMs,
    required this.text,
  });
}

class _ParsedDeploymentLog {
  final List<_DeploymentLogLine> lines;
  final String copyText;

  const _ParsedDeploymentLog({required this.lines, required this.copyText});
}

_ParsedDeploymentLog _parseDeploymentLog(String log) {
  final raw = (log).toString();
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const _ParsedDeploymentLog(lines: [], copyText: '');
  }

  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is List) {
        final lines = <_DeploymentLogLine>[];
        for (final entry in parsed) {
          if (entry is! Map) continue;
          final payload = entry['payload'];
          String text = '';
          if (payload is Map && payload['text'] is String) {
            text = (payload['text'] as String);
          } else if (entry['text'] is String) {
            text = (entry['text'] as String);
          }
          if (text.trim().isEmpty) continue;

          int? ts;
          if (payload is Map && payload['date'] is num) {
            ts = (payload['date'] as num).toInt();
          } else if (entry['created'] is num) {
            ts = (entry['created'] as num).toInt();
          }

          final type = (entry['type'] ?? '').toString();
          final stream = type == 'stderr'
              ? _LogStream.stderr
              : type == 'stdout'
                  ? _LogStream.stdout
                  : _LogStream.unknown;

          lines.add(
            _DeploymentLogLine(stream: stream, timestampMs: ts, text: text),
          );
        }

        if (lines.isNotEmpty) {
          return _ParsedDeploymentLog(
            lines: lines,
            copyText: lines.map((l) => l.text).join('\n'),
          );
        }
      }
    } catch (_) {
      // fall through to plain text
    }
  }

  final plainLines = raw.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
  return _ParsedDeploymentLog(
    lines: plainLines
        .map(
          (t) => _DeploymentLogLine(
            stream: _LogStream.unknown,
            timestampMs: null,
            text: t,
          ),
        )
        .toList(),
    copyText: raw,
  );
}
