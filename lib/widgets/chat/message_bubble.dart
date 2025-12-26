import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';
import 'expandable_text.dart';
import 'markdown_text.dart';
import 'tools/enhanced_tool_message.dart';
import 'tools/tool_utils.dart';

/// Message bubble widget for displaying chat messages
/// Note: Message actions are available via long press
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final VoidCallback? onTap;
  final Widget? userAccessory;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onTap,
    this.userAccessory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = message.role;
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...message.contents.map((content) {
          return _buildMessageContent(content, role, isUser, context);
        }),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      // Long press is available for message actions (copy, etc.)
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: isUser
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                          bottomLeft: Radius.circular(4.0),
                          bottomRight: Radius.circular(16.0),
                        ),
                      ),
                      child: contentColumn,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: contentColumn,
                    ),
            ),
            if (isUser && userAccessory != null) ...[
              const SizedBox(width: 6.0),
              userAccessory!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    MessageContent content,
    String role,
    bool isUser,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    if (content is TextMessageContent) {
      if (!isUser) {
        final r = role.toLowerCase().trim();
        if (r == 'warning') {
          return _AlertTextCard(
            kind: _AlertKind.warning,
            text: content.text,
          );
        }
        if (r == 'error') {
          return _AlertTextCard(
            kind: _AlertKind.error,
            text: content.text,
          );
        }

        final t = content.text.trim();
        if (t.startsWith('❌')) {
          return _AlertTextCard(kind: _AlertKind.error, text: content.text);
        }
        if (t.contains('✅') || t.contains('❌')) {
          final lower = t.toLowerCase();
          if (lower.contains('finished') ||
              lower.contains('failed') ||
              lower.contains('success') ||
              lower.contains('error')) {
            return _CompletionTextCard(
              success: t.contains('✅') && !t.contains('❌'),
              text: content.text,
            );
          }
        }
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: ExpandableText(
          text: content.text,
          maxLines: 6,
          isMarkdown: !isUser,
          style: TextStyle(
            color: textColor,
            fontSize: isUser ? 14.0 : 13.0,
            height: 1.25,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
    } else if (content is ThinkingMessageContent) {
      return _ThinkingCard(text: content.text);
    } else if (content is CodeMessageContent) {
      return _CodeCard(
        code: content.code,
        isToolResult:
            isUser ||
            (content.subtype ?? '')
                .toLowerCase()
                .trim()
                .startsWith('tool_result'),
      );
    } else if (content is ToolMessageContent) {
      return EnhancedToolMessage(content: content);
    } else if (content is GitCommitMessageContent) {
      return _GitCommitCard(content: content);
    } else if (content is GitPushMessageContent) {
      return _GitPushRow(content: content);
    } else if (content is ResultMessageContent) {
      return _ResultCard(payload: content.payload);
    } else if (content is DeploymentMessageContent) {
      return _DeploymentCard(content: content);
    } else if (content is ErrorMessageContent) {
      return _ErrorCard(content: content);
    } else if (content is CompletionMessageContent) {
      return _CompletionCard(content: content);
    } else if (content is RawMessageContent) {
      return _RawCard(payload: content.payload);
    }

    return const SizedBox.shrink();
  }
}

class _MessageCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const _MessageCard({
    required this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onCopy;
  final String? copyLabel;

  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onCopy,
    this.copyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(
                Icons.copy,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
                semanticLabel: copyLabel ?? 'Copy',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  final String text;

  const _ThinkingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _MessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.psychology_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Thinking',
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied thinking'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            copyLabel: 'Copy thinking',
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: text,
            maxLines: 4,
            isMarkdown: false,
            expandText: 'Show more',
            collapseText: 'Show less',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.3,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final bool isToolResult;

  const _CodeCard({required this.code, required this.isToolResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = _successTint(theme);
    final bg = isToolResult
        ? successTint.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
          )
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final title = isToolResult ? 'Tool execution result' : 'Code';
    final iconColor =
        isToolResult ? successTint : theme.colorScheme.primary;

    return _MessageCard(
      backgroundColor: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.code,
            iconColor: iconColor,
            title: title,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            copyLabel: 'Copy code',
          ),
          const SizedBox(height: 8),
          _ExpandableSelectableBlock(
            text: code,
            collapsedLines: 6,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.25,
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _GitCommitCard extends StatelessWidget {
  final GitCommitMessageContent content;

  const _GitCommitCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = content.files ?? const <String>[];

    return _MessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.commit,
            iconColor: theme.colorScheme.primary,
            title: content.message.isNotEmpty ? content.message : 'Commit',
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${files.length} changed file${files.length == 1 ? '' : 's'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in files)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 14,
                              color: f.toLowerCase().endsWith('.sql')
                                  ? _warningTint(theme)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SelectableText(
                                f,
                                maxLines: 2,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.2,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GitPushRow extends StatelessWidget {
  final GitPushMessageContent content;

  const _GitPushRow({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = _successTint(theme);
    final warningTint = _warningTint(theme);
    final isTimeout = content.error == 'timeout';
    final isSuccess = content.success && content.error == null;

    IconData icon;
    Color color;
    String label;

    if (isSuccess) {
      icon = Icons.check_circle;
      color = successTint;
      label = 'Git push succeeded';
    } else if (isTimeout) {
      icon = Icons.schedule;
      color = warningTint;
      label = 'Git push timeout';
    } else {
      icon = Icons.cancel;
      color = theme.colorScheme.error;
      label = 'Git push failed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (content.branch.isNotEmpty)
            Text(
              content.branch,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final dynamic payload;

  const _ResultCard({required this.payload});

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
    final successTint = _successTint(theme);
    final p = _unwrap(payload);
    final subtype = (p['subtype']?.toString() ?? 'unknown').toLowerCase();
    final isError = p['is_error'] == true || subtype == 'error';
    final resultText = p['result']?.toString() ?? '';
    final numTurns = _int(p['num_turns']) ?? 0;
    final durationMs = _int(p['duration_ms']) ?? 0;
    final durationSec = durationMs > 0 ? (durationMs / 1000).round() : 0;

    final usage = _map(p['usage']) ?? _map(_map(p['message'])?['usage']) ?? const <String, dynamic>{};
    final inputTokens = _int(p['input_tokens']) ??
        _int(usage['input_tokens']) ??
        _int(usage['prompt_tokens']);
    final outputTokens = _int(p['output_tokens']) ??
        _int(usage['output_tokens']) ??
        _int(usage['completion_tokens']);

    final Color tint = isError
        ? theme.colorScheme.error
        : subtype == 'success'
            ? successTint
            : theme.colorScheme.primary;

    final bg = tint.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10);
    final title = isError ? 'Error' : (subtype == 'success' ? 'Success' : 'Result');
    final icon = isError
        ? Icons.cancel
        : (subtype == 'success' ? Icons.check_circle : Icons.smart_toy_outlined);

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
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (numTurns > 0) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$numTurns turns',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (durationSec > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${durationSec}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
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

class _RawCard extends StatelessWidget {
  final dynamic payload;

  const _RawCard({required this.payload});

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

    return _MessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
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
          _ExpandableSelectableBlock(
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

class _ErrorCard extends StatelessWidget {
  final ErrorMessageContent content;

  const _ErrorCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = content.code != null ? 'Error ${content.code}' : 'Error';
    final detailsText = content.details != null ? prettyJson(content.details) : null;

    return _MessageCard(
      backgroundColor: theme.colorScheme.error.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.error_outline,
            iconColor: theme.colorScheme.error,
            title: title,
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: content.message,
            maxLines: 4,
            isMarkdown: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          if (detailsText != null && detailsText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExpandableSelectableBlock(
              text: detailsText,
              collapsedLines: 8,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.25,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final CompletionMessageContent content;

  const _CompletionCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint =
        content.success ? _successTint(theme) : theme.colorScheme.error;
    final bg = tint.withValues(alpha: 0.10);

    return _MessageCard(
      backgroundColor: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (content.details != null && content.details!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpandableText(
              text: content.details!,
              maxLines: 4,
              isMarkdown: false,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeploymentCard extends StatelessWidget {
  final DeploymentMessageContent content;

  const _DeploymentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = _successTint(theme);
    final warningTint = _warningTint(theme);
    final st = content.status.toLowerCase();
    final isSuccess = st == 'success';
    final isPending = st == 'pending';
    final isFailed = st == 'failed';

    final Color tint = isSuccess
        ? successTint
        : isPending
            ? warningTint
            : isFailed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant;

    final IconData icon = isSuccess
        ? Icons.check_circle
        : isPending
            ? Icons.hourglass_empty
            : isFailed
                ? Icons.error
                : Icons.info;

    return _MessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: icon,
            iconColor: tint,
            title: 'Deployment${content.environment != null && content.environment!.isNotEmpty ? ' · ${content.environment}' : ''}',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                content.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          if (content.message != null && content.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content.message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          if (content.url != null && content.url!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: tint),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    content.url!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableSelectableBlock extends StatefulWidget {
  final String text;
  final int collapsedLines;
  final TextStyle? style;

  const _ExpandableSelectableBlock({
    required this.text,
    required this.collapsedLines,
    this.style,
  });

  @override
  State<_ExpandableSelectableBlock> createState() =>
      _ExpandableSelectableBlockState();
}

class _ExpandableSelectableBlockState extends State<_ExpandableSelectableBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.text.split('\n').length;
    final canExpand = lines > widget.collapsedLines || widget.text.length > 280;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            widget.text,
            maxLines: _expanded ? null : widget.collapsedLines,
            style: widget.style,
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _AlertKind { error, warning }

class _AlertTextCard extends StatelessWidget {
  final _AlertKind kind;
  final String text;

  const _AlertTextCard({required this.kind, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color tint = switch (kind) {
      _AlertKind.error => theme.colorScheme.error,
      _AlertKind.warning => _warningTint(theme),
    };

    final String title = switch (kind) {
      _AlertKind.error => 'Error',
      _AlertKind.warning => 'Warning',
    };

    return _MessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: text,
            maxLines: 3,
            isMarkdown: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tint.withValues(alpha: 0.92),
              height: 1.3,
              fontSize: 12.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionTextCard extends StatelessWidget {
  final bool success;
  final String text;

  const _CompletionTextCard({required this.success, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color tint =
        success ? _successTint(theme) : theme.colorScheme.error;

    return _MessageCard(
      backgroundColor: tint.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ExpandableText(
              text: text,
              maxLines: 3,
              isMarkdown: false,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                height: 1.25,
                fontSize: 12.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _successTint(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade700;
}

Color _warningTint(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.amber.shade300
      : Colors.amber.shade800;
}
