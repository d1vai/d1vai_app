import 'package:flutter/material.dart';

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
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
                  'Preview: ${_getDeploymentLabel(previewUrl)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
            tooltip: 'Refresh Preview',
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
