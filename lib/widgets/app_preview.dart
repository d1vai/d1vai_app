import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'card.dart';
import 'phone_frame_web_preview.dart';

class AppPreview extends StatefulWidget {
  final String? previewUrl;
  final String? projectName;

  const AppPreview({
    super.key,
    this.previewUrl,
    this.projectName,
  });

  @override
  State<AppPreview> createState() => _AppPreviewState();
}

class _AppPreviewState extends State<AppPreview> {
  final _previewKey = GlobalKey<PhoneFrameWebPreviewState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final had = oldWidget.previewUrl != null && oldWidget.previewUrl!.isNotEmpty;
    final has = widget.previewUrl != null && widget.previewUrl!.isNotEmpty;
    if (had && !has && _isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _previewKey.currentState?.reload();
  }

  void _openInBrowser() async {
    final appUrl = widget.previewUrl;
    if (appUrl == null || appUrl.isEmpty) return;

    final uri = Uri.parse(appUrl);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.selectionClick();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $appUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPreviewUrl =
        widget.previewUrl != null && widget.previewUrl!.isNotEmpty;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_android, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.projectName ?? 'Your deployed application',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasPreviewUrl) ...[
            IconButton(
              onPressed: _refresh,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh,
                        key: ValueKey('refresh'),
                      ),
              ),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in Browser',
            ),
          ],
        ],
      ),
    );

    final footer = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasPreviewUrl
                  ? 'Preview updates automatically. Use the refresh button to reload.'
                  : 'No preview available. Deploy your project to see preview.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    return CustomCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,

          // Preview Container (Simulated Phone Frame)
          PhoneFrameWebPreview(
            key: _previewKey,
            url: widget.previewUrl,
            webViewHeight: 400,
            margin: const EdgeInsets.all(16),
            onLoadingChanged: (value) {
              if (!mounted) return;
              setState(() {
                _isLoading = value;
              });
            },
          ),

          // Info Footer
          footer,
        ],
      ),
    );
  }
}
