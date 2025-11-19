import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AppDetailScreen extends StatelessWidget {
  final String slug;

  const AppDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('App: $slug')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://d1vai.com/apps/$slug'),
        ),
      ),
    );
  }
}
