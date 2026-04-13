import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Best-effort URL -> in-app route resolver.
///
/// This is a lightweight step toward full universal links / deep links:
/// - Recognize common d1v.ai / d1vai.com URLs and jump via go_router
/// - Otherwise fall back to external browser
class LinkNavigator {
  static String? routeFor(Uri uri) {
    final host = uri.host.toLowerCase();
    final seg = uri.pathSegments;

    // Docs.
    final isDocsHost =
        host == 'www.d1v.ai' || host == 'd1v.ai' || host == 'docs.d1v.ai';
    if (seg.isNotEmpty && isDocsHost && seg.first == 'docs') {
      if (seg.length >= 2) {
        return '/docs/${seg[1]}';
      }
      return '/docs';
    }

    if (seg.isNotEmpty &&
        (host == 'www.d1v.ai' || host == 'd1v.ai') &&
        seg.first == 'u' &&
        seg.length >= 2) {
      return '/u/${seg[1]}';
    }

    if ((host == 'www.d1v.ai' || host == 'd1v.ai') &&
        uri.path == '/login' &&
        (uri.queryParameters['invite'] ?? '').trim().isNotEmpty) {
      final invite = Uri.encodeQueryComponent(
        uri.queryParameters['invite']!.trim(),
      );
      return '/login?invite=$invite';
    }

    if ((host == 'www.d1v.ai' || host == 'd1v.ai') && uri.path == '/openapi') {
      final next = Uri(
        path: '/openapi',
        queryParameters: {
          if ((uri.queryParameters['prompt'] ?? '').trim().isNotEmpty)
            'prompt': uri.queryParameters['prompt']!.trim(),
          if ((uri.queryParameters['spec'] ?? '').trim().isNotEmpty)
            'spec': uri.queryParameters['spec']!.trim(),
        },
      );
      return next.toString();
    }

    if ((host == 'api.d1v.ai' || host == 'api.desci.cyou') &&
        uri.path.endsWith('/docs')) {
      return '/api-docs';
    }

    if (seg.isEmpty) return null;

    // Marketplace apps (d1vai.com/apps/:slug).
    if ((host == 'd1vai.com' || host.endsWith('.d1vai.com')) &&
        seg.first == 'apps' &&
        seg.length >= 2) {
      return '/apps/${seg[1]}';
    }

    // Community posts (www.d1v.ai/c/:slug).
    if ((host == 'www.d1v.ai' || host == 'd1v.ai') &&
        seg.first == 'c' &&
        seg.length >= 2) {
      return '/c/${seg[1]}';
    }

    return null;
  }

  static Future<bool> tryNavigate(BuildContext context, Uri uri) async {
    final route = routeFor(uri);
    if (route == null) return false;
    final current = GoRouterState.of(context).matchedLocation;
    if (current == route) {
      // Keep the current webview navigation when it already points to
      // the same in-app route (prevents blank page from canceled initial load).
      return false;
    }
    context.go(route);
    return true;
  }

  static Future<void> openExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
