import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ProjectChatWebView extends StatelessWidget {
  final String url;

  const ProjectChatWebView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      contextMenu: ContextMenu(),
      initialUrlRequest: URLRequest(url: WebUri(url)),
    );
  }
}
