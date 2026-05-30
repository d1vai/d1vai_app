import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../widgets/inapp_webview_settings.dart';
import '../widgets/web_subpage_app_bar.dart';

class CommunityComponentPreviewScreen extends StatefulWidget {
  final String slug;
  final String title;

  const CommunityComponentPreviewScreen({
    super.key,
    required this.slug,
    required this.title,
  });

  @override
  State<CommunityComponentPreviewScreen> createState() =>
      _CommunityComponentPreviewScreenState();
}

class _CommunityComponentPreviewScreenState
    extends State<CommunityComponentPreviewScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;

  Uri get _url => Uri.parse(
        'https://www.d1v.ai/compreview/${Uri.encodeComponent(widget.slug)}',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WebSubPageAppBar(
        title: Text(widget.title),
        fallbackRoute: '/community',
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
            initialSettings: buildAppWebViewSettings(),
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
            },
            onLoadStop: (controller, url) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _progress = 1;
              });
            },
            onReceivedError: (controller, request, error) {
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text('Failed to load component preview'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _controller?.loadUrl(
                            urlRequest: URLRequest(url: WebUri(_url.toString())),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
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
