import 'package:flutter/material.dart';

import '../../../models/message.dart';
import '../file_type_visual.dart';
import '../project_chat/code_tab/code_tab_file_detail_bottom_sheet.dart';
import 'message_card_base.dart';
import '../../snackbar_helper.dart';

class ChatGitCommitCard extends StatelessWidget {
  final GitCommitMessageContent content;

  const ChatGitCommitCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = content.files ?? const <String>[];
    final projectId = (content.projectId ?? '').trim();
    final sqlFiles = files.where((f) => f.toLowerCase().endsWith('.sql')).toList();
    final otherFiles = files.where((f) => !f.toLowerCase().endsWith('.sql')).toList();
    const fileTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11.5,
      height: 1.2,
    );
    final firstLineHeight =
        (fileTextStyle.fontSize ?? 11.5) * (fileTextStyle.height ?? 1.2);
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.35 : 0.6,
    );

    Future<void> openFile(String path, {bool autoOpenMigration = false}) async {
      if (projectId.isEmpty) {
        SnackBarHelper.showError(
          context,
          title: 'Missing project',
          message: 'Cannot open file details without project_id.',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      await showProjectFileDetailBottomSheet(
        context,
        projectId: projectId,
        filePath: path,
        autoOpenMigration: autoOpenMigration,
      );
    }

    Widget sectionLabel(String text, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: (color ?? theme.colorScheme.onSurfaceVariant).withValues(
              alpha: 0.9,
            ),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return ChatMessageCard(
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatCardHeader(
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
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 3,
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sqlFiles.isNotEmpty) ...[
                              sectionLabel(
                                'SQL migrations',
                                color: Colors.amber.shade700,
                              ),
                              for (final f in sqlFiles)
                                _FileRow(
                                  filePath: f,
                                  firstLineHeight: firstLineHeight,
                                  textStyle: fileTextStyle,
                                  onOpen: () => openFile(f),
                                  trailing: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.play_arrow,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    tooltip: 'Run SQL migration',
                                    onPressed: () => openFile(
                                      f,
                                      autoOpenMigration: true,
                                    ),
                                  ),
                                ),
                              if (otherFiles.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                            if (otherFiles.isNotEmpty) ...[
                              sectionLabel('Other files'),
                              for (final f in otherFiles)
                                _FileRow(
                                  filePath: f,
                                  firstLineHeight: firstLineHeight,
                                  textStyle: fileTextStyle,
                                  onOpen: () => openFile(f),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String filePath;
  final double firstLineHeight;
  final TextStyle textStyle;
  final VoidCallback onOpen;
  final Widget? trailing;

  const _FileRow({
    required this.filePath,
    required this.firstLineHeight,
    required this.textStyle,
    required this.onOpen,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = fileTypeVisual(theme, filePath);
    final iconColor =
        (visual.color ?? theme.colorScheme.onSurfaceVariant).withValues(
          alpha: 0.85,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 18,
                  height: firstLineHeight,
                  child: Center(
                    child: Icon(visual.icon, size: 14, color: iconColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    filePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ] else ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatGitPushRow extends StatelessWidget {
  final GitPushMessageContent content;

  const ChatGitPushRow({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successTint = chatSuccessTint(theme);
    final warningTint = chatWarningTint(theme);
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
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
