import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../widgets/share_sheet.dart';

class AppDetailScreen extends StatelessWidget {
  final String slug;

  const AppDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final url = ShareLinks.marketplaceAppBySlug(slug);
    return Scaffold(
      appBar: AppBar(
        title: Text('App: $slug'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () {
              ShareSheet.show(
                context,
                url: url,
                title: 'App: $slug',
              );
            },
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(url.toString()),
        ),
      ),
    );
  }
}
