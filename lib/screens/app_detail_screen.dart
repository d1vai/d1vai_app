import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/link_navigator.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';

class AppDetailScreen extends StatefulWidget {
  final String slug;

  const AppDetailScreen({super.key, required this.slug});

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pull;
  bool _hasError = false;
  bool _isLoading = true;
  double _progress = 0;

  Uri get _url => ShareLinks.marketplaceAppBySlug(widget.slug);

  @override
  void initState() {
    super.initState();
    _pull = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.deepPurple),
      onRefresh: () async {
        try {
          await _controller?.reload();
        } catch (_) {
          _pull?.endRefreshing();
        }
      },
    );
  }

  @override
  void dispose() {
    _pull = null;
    _controller = null;
    super.dispose();
  }

  Future<void> _openOfficial() async {
    final uri = _url;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    SnackBarHelper.showError(
      context,
      title: 'Open failed',
      message: 'Cannot open link',
    );
  }

  Future<void> _openPreview() async {
    try {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_url.toString())),
      );
    } catch (_) {
      await _controller?.reload();
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _url.toString()));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'Link copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App: ${widget.slug}'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () {
              ShareSheet.show(
                context,
                url: _url,
                title: 'App: ${widget.slug}',
                message: 'Open this app in the d1vai marketplace.',
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress > 0 && _progress < 1 ? _progress : null,
                  minHeight: 2,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_url.toString())),
            pullToRefreshController: _pull,
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final webUri = navigationAction.request.url;
              if (webUri == null) return NavigationActionPolicy.ALLOW;
              final uri = Uri.tryParse(webUri.toString());
              if (uri == null) return NavigationActionPolicy.ALLOW;
              if (uri.scheme != 'http' && uri.scheme != 'https') {
                await LinkNavigator.openExternal(uri);
                return NavigationActionPolicy.CANCEL;
              }
              final handled = await LinkNavigator.tryNavigate(context, uri);
              return handled
                  ? NavigationActionPolicy.CANCEL
                  : NavigationActionPolicy.ALLOW;
            },
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (controller, url) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _hasError = false;
                _progress = 0;
              });
            },
            onProgressChanged: (controller, progress) {
              if (!mounted) return;
              setState(() => _progress = (progress / 100).clamp(0.0, 1.0));
              if (progress >= 100) _pull?.endRefreshing();
            },
            onLoadStop: (controller, url) {
              _pull?.endRefreshing();
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _progress = 1;
              });
            },
            onReceivedError: (controller, request, error) {
              _pull?.endRefreshing();
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
          ),
          if (_hasError)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text('Failed to load page'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openPreview,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openOfficial,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Browser'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openOfficial,
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Official'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openPreview,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
