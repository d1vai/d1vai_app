import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AppPreview extends StatefulWidget {
  final String projectSlug;
  final String? projectName;

  const AppPreview({
    super.key,
    required this.projectSlug,
    this.projectName,
  });

  @override
  State<AppPreview> createState() => _AppPreviewState();
}

class _AppPreviewState extends State<AppPreview> {
  InAppWebViewController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_controller != null) {
      setState(() {
        _hasError = false;
      });
      await _controller!.reload();
    }
  }

  void _openInBrowser() {
    final appUrl = 'https://d1vai.com/apps/${widget.projectSlug}';
    // In a real implementation, you'd use url_launcher package
    // For now, we'll show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open in Browser'),
        content: Text('This would open:\n$appUrl'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
  }

  void _onLoadStart(InAppWebViewController controller, Uri? url) {
    setState(() {
      _hasError = false;
    });
  }

  void _onLoadStop(InAppWebViewController controller, Uri? url) {
    // Load completed
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    // Progress updated
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Preview',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.projectName ?? 'Your deployed application',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
                IconButton(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open in Browser',
                ),
              ],
            ),
          ),

          // Preview Container (Simulated Phone Frame)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Phone Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '9:41',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.signal_cellular_4_bar,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.wifi,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.battery_full,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // WebView Container
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _hasError
                      ? _buildErrorState()
                      : InAppWebView(
                          contextMenu: ContextMenu(),
                          initialUrlRequest: URLRequest(
                            url: WebUri('https://d1vai.com/apps/${widget.projectSlug}'),
                          ),
                          onWebViewCreated: _onWebViewCreated,
                          onLoadStart: _onLoadStart,
                          onLoadStop: _onLoadStop,
                          onProgressChanged: _onProgressChanged,
                        ),
                ),
              ],
            ),
          ),

          // Info Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview updates automatically. Use the refresh button to reload.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load preview',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The app may not be deployed yet or the URL is invalid',
              style: TextStyle(
                color: Colors.grey.shade600,
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
