import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ProjectChatWebView extends StatefulWidget {
  final String url;

  const ProjectChatWebView({super.key, required this.url});

  @override
  State<ProjectChatWebView> createState() => _ProjectChatWebViewState();
}

class _ProjectChatWebViewState extends State<ProjectChatWebView>
    with AutomaticKeepAliveClientMixin {
  late Widget _webView;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _webView = _buildWebView();
  }

  @override
  void didUpdateWidget(covariant ProjectChatWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _webView = _buildWebView();
    }
  }

  Widget _buildWebView() {
    return InAppWebView(
      contextMenu: ContextMenu(),
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: _webView);
  }
}
