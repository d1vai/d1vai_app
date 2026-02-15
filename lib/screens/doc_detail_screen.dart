import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/link_navigator.dart';
import '../widgets/share_sheet.dart';
import '../widgets/snackbar_helper.dart';

class DocDetailScreen extends StatefulWidget {
  final String slug;

  const DocDetailScreen({super.key, required this.slug});

  @override
  State<DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends State<DocDetailScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;

  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;

  Uri get _docUrl {
    if (widget.slug == 'legal-restrictions') {
      return Uri.parse('https://www.d1v.ai/docs/legal-restrictions');
    }
    return Uri.parse('https://docs.d1v.ai/docs/${widget.slug}');
  }

  static const _jsHandlerCopyCode = 'd1vCopyCode';
  static const _prefsKeyRecent = 'docs_recent_slugs';

  late final Future<SharedPreferences> _prefsFuture;
  Timer? _scrollDebounce;
  int _lastSavedScrollY = -1;
  bool _didRestoreScroll = false;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    unawaited(_recordRecent());
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.deepPurple),
      onRefresh: () async {
        try {
          await _controller?.reload();
        } catch (_) {
          _pullToRefreshController?.endRefreshing();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _pullToRefreshController = null;
    _controller = null;
    super.dispose();
  }

  String get _prefsKeyScrollY => 'doc_scroll_y:${widget.slug}';

  Future<void> _recordRecent() async {
    final prefs = await _prefsFuture;
    final current = widget.slug.trim();
    if (current.isEmpty) return;

    final list = prefs.getStringList(_prefsKeyRecent) ?? <String>[];
    final next = <String>[current, ...list.where((s) => s != current)];
    // Keep it lightweight.
    if (next.length > 8) {
      next.removeRange(8, next.length);
    }
    await prefs.setStringList(_prefsKeyRecent, next);
  }

  Future<int?> _loadSavedScrollY() async {
    final prefs = await _prefsFuture;
    return prefs.getInt(_prefsKeyScrollY);
  }

  Future<void> _saveScrollY(int y) async {
    if (y < 0) return;
    final prefs = await _prefsFuture;
    await prefs.setInt(_prefsKeyScrollY, y);
  }

  void _scheduleSaveScrollY(int y) {
    // Avoid spamming disk while scrolling.
    if ((y - _lastSavedScrollY).abs() < 12) return;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 450), () async {
      _lastSavedScrollY = y;
      await _saveScrollY(y);
    });
  }

  Future<void> _restoreScrollIfNeeded() async {
    if (_didRestoreScroll) return;
    _didRestoreScroll = true;

    final saved = await _loadSavedScrollY();
    if (saved == null || saved <= 0) return;

    // Wait a tick so layout settles.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _controller?.evaluateJavascript(
      source: 'window.scrollTo(0, ${saved.toString()});',
    );
  }

  Future<void> _injectCodeCopy() async {
    // Add a lightweight "Copy" button to code blocks for quick reuse on mobile.
    // Uses a JS handler to bridge clipboard access back to Flutter.
    await _controller?.evaluateJavascript(
      source:
          '''
(() => {
  try {
    const FLAG = '__d1v_copy_injected__';
    if (window[FLAG]) return;
    window[FLAG] = true;

    const BTN_ATTR = 'data-d1v-copy-btn';
    const PRE_ATTR = 'data-d1v-copy';

    function ensureButtons() {
      const blocks = document.querySelectorAll('pre');
      blocks.forEach((pre) => {
        if (!pre || pre.getAttribute(PRE_ATTR) === '1') return;

        // If the page already has a copy button, avoid duplicates.
        if (pre.querySelector('button[aria-label*="Copy"], button[title*="Copy"], button[title*="copy"]')) {
          pre.setAttribute(PRE_ATTR, '1');
          return;
        }

        pre.setAttribute(PRE_ATTR, '1');
        if (!pre.style.position) pre.style.position = 'relative';

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = 'Copy';
        btn.setAttribute(BTN_ATTR, '1');
        btn.style.cssText = [
          'position:absolute',
          'top:8px',
          'right:8px',
          'z-index:2',
          'padding:6px 10px',
          'border-radius:999px',
          'border:1px solid rgba(127,127,127,0.35)',
          'background:rgba(0,0,0,0.55)',
          'color:#fff',
          'font-size:12px',
          'font-weight:700',
          'cursor:pointer',
          'user-select:none',
        ].join(';');

        btn.addEventListener('click', (e) => {
          try {
            e.preventDefault();
            e.stopPropagation();
            const codeEl = pre.querySelector('code');
            const text = (codeEl ? codeEl.innerText : pre.innerText) || '';
            if (!text.trim()) return;
            window.flutter_inappwebview.callHandler('$_jsHandlerCopyCode', text);
            const old = btn.textContent;
            btn.textContent = 'Copied';
            setTimeout(() => { btn.textContent = old || 'Copy'; }, 900);
          } catch (_) {}
        });

        pre.appendChild(btn);
      });
    }

    ensureButtons();
    const obs = new MutationObserver(() => ensureButtons());
    obs.observe(document.body, { childList: true, subtree: true });
  } catch (_) {}
})();
''',
    );
  }

  Future<void> _openExternal() async {
    final uri = _docUrl;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Docs: ${widget.slug}'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () {
              ShareSheet.show(
                context,
                url: _docUrl,
                title: 'd1v.ai docs',
                message: '/docs/${widget.slug}',
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
            initialUrlRequest: URLRequest(url: WebUri(_docUrl.toString())),
            pullToRefreshController: _pullToRefreshController,
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
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: _jsHandlerCopyCode,
                callback: (args) async {
                  final ctx = context;
                  final text = args.isNotEmpty ? args.first?.toString() : null;
                  if (text == null || text.trim().isEmpty) return null;
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!ctx.mounted) return null;
                  SnackBarHelper.showSuccess(
                    ctx,
                    title: 'Copied',
                    message: 'Code block copied. Paste it anywhere.',
                  );
                  return null;
                },
              );
            },
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
              setState(() {
                _progress = (progress / 100).clamp(0.0, 1.0);
              });
              if (progress >= 100) {
                _pullToRefreshController?.endRefreshing();
              }
            },
            onLoadStop: (controller, url) async {
              _pullToRefreshController?.endRefreshing();
              await _injectCodeCopy();
              await _restoreScrollIfNeeded();
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _progress = 1;
              });
            },
            onReceivedError: (controller, request, error) {
              _pullToRefreshController?.endRefreshing();
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
            onScrollChanged: (controller, x, y) {
              _scheduleSaveScrollY(y);
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load doc',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _docUrl.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              setState(() {
                                _hasError = false;
                                _isLoading = true;
                              });
                              await _controller?.reload();
                            },
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
