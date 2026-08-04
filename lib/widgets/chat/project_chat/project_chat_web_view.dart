import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../inapp_webview_settings.dart';

class ProjectChatWebView extends StatefulWidget {
  final String url;

  const ProjectChatWebView({super.key, required this.url});

  @override
  State<ProjectChatWebView> createState() => _ProjectChatWebViewState();
}

class _ProjectChatWebViewState extends State<ProjectChatWebView>
    with AutomaticKeepAliveClientMixin {
  InAppWebViewController? _controller;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant ProjectChatWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _hasError = false;
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Stack(
        children: [
          InAppWebView(
            contextMenu: ContextMenu(),
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: buildAppWebViewSettings(),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (controller, url) {
              if (mounted) setState(() => _hasError = false);
            },
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame != true || !mounted) return;
              setState(() => _hasError = true);
            },
          ),
          if (_hasError)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _controller?.reload(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
