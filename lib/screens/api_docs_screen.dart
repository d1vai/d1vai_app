import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/theme/locale_font_helper.dart';
import '../l10n/app_localizations.dart';
import '../utils/link_navigator.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/web_subpage_app_bar.dart';

class ApiDocsScreen extends StatefulWidget {
  final String? title;
  final String? specUrl;
  final bool preferOpenApiShell;
  final bool hideHeader;

  const ApiDocsScreen({
    super.key,
    this.title,
    this.specUrl,
    this.preferOpenApiShell = false,
    this.hideHeader = false,
  });

  @override
  State<ApiDocsScreen> createState() => _ApiDocsScreenState();
}

class _ApiDocsScreenState extends State<ApiDocsScreen> {
  static const String _defaultOpenApiSpecUrl =
      'https://api.desci.cyou/api/openapi.json';
  static const String _defaultOpenApiTitle = 'OpenAPI Docs';

  InAppWebViewController? _controller;
  PullToRefreshController? _pull;

  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;
  bool _didOpenExternally = false;

  Uri get _docsUrl {
    final base = Uri.tryParse(ApiClient.baseUrl);
    if (base == null) return Uri.parse('https://api.d1v.ai/docs');
    return base.replace(path: '${base.path}/docs');
  }

  String get _resolvedTitle {
    final next = (widget.title ?? '').trim();
    if (next.isNotEmpty) return next;
    final loc = AppLocalizations.of(context);
    if (widget.preferOpenApiShell) {
      return loc?.translate('api_docs_openapi_title') ?? _defaultOpenApiTitle;
    }
    return loc?.translate('api_docs_title') ?? 'API Documentation';
  }

  String? get _resolvedSpecUrl {
    final next = (widget.specUrl ?? '').trim();
    if (next.isNotEmpty) return next;
    if (widget.preferOpenApiShell) return _defaultOpenApiSpecUrl;
    return null;
  }

  Uri get _viewUrl {
    final spec = _resolvedSpecUrl;
    if (spec == null) return _docsUrl;
    return ShareLinks.openApiDocs(
      prompt: _resolvedTitle,
      spec: spec,
      hideHeader: widget.hideHeader,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_didOpenExternally || !mounted) return;
        _didOpenExternally = true;
        await _openExternal();
        if (!mounted) return;
        await Navigator.of(context).maybePop();
      });
      return;
    }
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
    final loc = AppLocalizations.of(context);
    final uri = _viewUrl;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: loc?.translate('docs_open_failed_title') ?? 'Open failed',
        message:
            loc?.translate('docs_open_failed_message') ?? 'Cannot open link',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      return Scaffold(
        appBar: widget.hideHeader
            ? null
            : WebSubPageAppBar(
                title: Text(
                  _resolvedTitle,
                  style: LocaleFontHelper.localizedTitleStyle(
                    context,
                    theme.textTheme.titleLarge,
                  ),
                ),
                fallbackRoute: '/docs',
              ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  loc?.translate('api_docs_opening_in_browser') ??
                      'Opening API docs in your browser...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.hideHeader
          ? null
          : WebSubPageAppBar(
              title: Text(
                _resolvedTitle,
                style: LocaleFontHelper.localizedTitleStyle(
                  context,
                  Theme.of(context).textTheme.titleLarge,
                ),
              ),
              fallbackRoute: '/docs',
              actions: [
                IconButton(
                  tooltip: loc?.translate('docs_share') ?? 'Share',
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    ShareSheet.show(
                      context,
                      url: _viewUrl,
                      title: _resolvedTitle,
                      message: _resolvedSpecUrl ?? _viewUrl.toString(),
                    );
                  },
                ),
                IconButton(
                  tooltip:
                      loc?.translate('docs_open_in_browser') ??
                      'Open in browser',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: _openExternal,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: _isLoading
                    ? LinearProgressIndicator(
                        value: _progress > 0 && _progress < 1
                            ? _progress
                            : null,
                        minHeight: 2,
                      )
                    : const SizedBox(height: 2),
              ),
            ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_viewUrl.toString())),
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
                      Text(
                        loc?.translate('api_docs_load_failed_title') ??
                            'Failed to load API docs',
                        style: LocaleFontHelper.localizedTitleStyle(
                          context,
                          Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _controller?.reload(),
                            icon: const Icon(Icons.refresh),
                            label: Text(loc?.translate('retry') ?? 'Retry'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openExternal,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              loc?.translate('docs_browser') ?? 'Browser',
                            ),
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
