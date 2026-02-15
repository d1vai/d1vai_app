import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../utils/link_navigator.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';

class ApiDocsScreen extends StatefulWidget {
  const ApiDocsScreen({super.key});

  @override
  State<ApiDocsScreen> createState() => _ApiDocsScreenState();
}

class _ApiDocsScreenState extends State<ApiDocsScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pull;

  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;

  Uri get _docsUrl {
    final base = Uri.tryParse(ApiClient.baseUrl);
    if (base == null) return Uri.parse('https://api.d1v.ai/docs');
    return base.replace(path: '${base.path}/docs');
  }

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

  Future<void> _openExternal() async {
    final uri = _docsUrl;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Open failed',
        message: 'Cannot open link',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('API Documentation'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () {
              ShareSheet.show(
                context,
                url: _docsUrl,
                title: 'API docs',
                message: _docsUrl.toString(),
              );
            },
          ),
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternal,
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
            initialUrlRequest: URLRequest(url: WebUri(_docsUrl.toString())),
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
                      const Text('Failed to load API docs'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _controller?.reload(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openExternal,
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
    );
  }
}
