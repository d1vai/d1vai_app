import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProjectChatPreviewHeader extends StatelessWidget {
  final String previewUrl;
  final VoidCallback onRefreshPreview;
  final VoidCallback onOpenInNewTab;

  const ProjectChatPreviewHeader({
    super.key,
    required this.previewUrl,
    required this.onRefreshPreview,
    required this.onOpenInNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = _getDeploymentLabel(previewUrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.web, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    host,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  previewUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefreshPreview,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: previewUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy link',
          ),
          IconButton(
            onPressed: onOpenInNewTab,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Browser',
          ),
        ],
      ),
    );
  }
}

String _getDeploymentLabel(String url) {
  if (url.isEmpty) return 'Configure later';
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (_) {
    return url;
  }
}
