import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'card.dart';

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

class _AppPreviewState extends State<AppPreview>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _hasError = false;
  bool _isLoading = false;
  double _progress = 0;
  late final AnimationController _glareController;

  @override
  void initState() {
    super.initState();
    _glareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glareController.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_controller != null && mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
        _progress = 0;
      });
      try {
        await _controller!.reload();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
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

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
  }

  void _onLoadStart(InAppWebViewController controller, Uri? url) {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _progress = 0;
    });
  }

  void _onLoadStop(InAppWebViewController controller, Uri? url) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _progress = 1;
    });
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (!mounted) return;
    final next = (progress / 100).clamp(0.0, 1.0);
    if ((next - _progress).abs() < 0.01 && progress != 100) return;
    setState(() {
      _progress = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasPreviewUrl = widget.previewUrl != null && widget.previewUrl!.isNotEmpty;

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
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF09090B) : const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color.alphaBlend(
                  colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.14),
                  colorScheme.outlineVariant,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  if (_isLoading && hasPreviewUrl)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _glareController,
                        builder: (context, _) {
                          final t = _glareController.value;
                          final glare = colorScheme.primary.withValues(
                            alpha: isDark ? (0.10 + 0.10 * t) : (0.08 + 0.08 * t),
                          );
                          return IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1 + 2 * t, -1),
                                  end: Alignment(0 + 2 * t, 1),
                                  colors: [
                                    Colors.transparent,
                                    glare,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Column(
                    children: [
                      // Phone Status Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '9:41',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.signal_cellular_4_bar,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.wifi,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.battery_full,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // WebView Container
                      Stack(
                        children: [
                          Container(
                            height: 400,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: hasPreviewUrl
                                ? (_hasError
                                    ? _buildErrorState()
                                    : AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeIn,
                                        child: InAppWebView(
                                          key: ValueKey(widget.previewUrl),
                                          contextMenu: ContextMenu(),
                                          initialUrlRequest: URLRequest(
                                            url: WebUri(widget.previewUrl!),
                                          ),
                                          onWebViewCreated: _onWebViewCreated,
                                          onLoadStart: _onLoadStart,
                                          onLoadStop: _onLoadStop,
                                          onProgressChanged:
                                              _onProgressChanged,
                                        ),
                                      ))
                                : _buildNoPreviewState(),
                          ),
                          if (hasPreviewUrl)
                            Positioned(
                              left: 10,
                              right: 10,
                              top: 8,
                              child: AnimatedOpacity(
                                opacity: _isLoading ? 1 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: _isLoading ? _progress : null,
                                    minHeight: 3,
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Info Footer
          footer,
        ],
      ),
    );
  }

  Widget _buildNoPreviewState() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.web_asset_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No preview available',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deploy your project to see preview',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load preview',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The app may not be deployed yet or the URL is invalid',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
