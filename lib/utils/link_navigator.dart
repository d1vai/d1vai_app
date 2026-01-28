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
    if (seg.isEmpty) return null;

    // Docs.
    if (host == 'docs.d1v.ai' && seg.first == 'docs' && seg.length >= 2) {
      return '/docs/${seg[1]}';
    }

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

    // In-app docs routes when sharing an app link to itself.
    if ((host == 'www.d1v.ai' || host == 'd1v.ai') &&
        seg.first == 'docs' &&
        seg.length >= 2) {
      return '/docs/${seg[1]}';
    }

    return null;
  }

  static Future<bool> tryNavigate(BuildContext context, Uri uri) async {
    final route = routeFor(uri);
    if (route == null) return false;
    context.go(route);
    return true;
  }

  static Future<void> openExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

