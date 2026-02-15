import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PhoneFrameWebPreview extends StatefulWidget {
  final String? url;
  final double? height;
  final double webViewHeight;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool showStatusBar;
  final double statusBarHeight;
  final double frameBorderRadius;
  final double screenBorderRadius;
  final double pageScale;
  final bool allowParentVerticalScroll;

  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<bool>? onErrorChanged;

  const PhoneFrameWebPreview({
    super.key,
    required this.url,
    this.height,
    this.webViewHeight = 400,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.showStatusBar = true,
    this.statusBarHeight = 28,
    this.frameBorderRadius = 24,
    this.screenBorderRadius = 12,
    this.pageScale = 1.0,
    this.allowParentVerticalScroll = false,
    this.onLoadingChanged,
    this.onProgressChanged,
    this.onErrorChanged,
  });

  @override
  State<PhoneFrameWebPreview> createState() => PhoneFrameWebPreviewState();
}

class PhoneFrameWebPreviewState extends State<PhoneFrameWebPreview>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _hasError = false;
  bool _isLoading = false;
  double _progress = 0;
  late final AnimationController _glareController;

  bool get _hasUrl => widget.url != null && widget.url!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _glareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _glareController.dispose();
    _controller = null;
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    setState(() {
      _isLoading = value;
    });
    if (value) {
      if (!_glareController.isAnimating) {
        _glareController.repeat(reverse: true);
      }
    } else {
      if (_glareController.isAnimating) {
        _glareController.stop();
      }
    }
    widget.onLoadingChanged?.call(value);
  }

  void _setProgress(double value) {
    if ((value - _progress).abs() < 0.01 && value != 1.0) return;
    setState(() {
      _progress = value;
    });
    widget.onProgressChanged?.call(value);
  }

  void _setError(bool value) {
    if (_hasError == value) return;
    setState(() {
      _hasError = value;
    });
    widget.onErrorChanged?.call(value);
  }

  Future<void> reload() async {
    if (_controller == null) return;
    _setError(false);
    _setLoading(true);
    _setProgress(0);
    try {
      await _controller!.reload();
    } catch (_) {
      if (!mounted) return;
      _setError(true);
      _setLoading(false);
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
  }

  void _onLoadStart(InAppWebViewController controller, Uri? url) {
    if (!mounted) return;
    _setError(false);
    _setLoading(true);
    _setProgress(0);
  }

  void _onLoadStop(InAppWebViewController controller, Uri? url) {
    if (!mounted) return;
    _setLoading(false);
    _setProgress(1);
    _applyPageScale();
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (!mounted) return;
    _setProgress((progress / 100).clamp(0.0, 1.0));
  }

  Future<void> _applyPageScale() async {
    final controller = _controller;
    if (controller == null) return;
    final scale = widget.pageScale;
    if (scale == 1.0) return;
    final clamped = scale.clamp(0.5, 2.0);
    try {
      await controller.evaluateJavascript(
        source:
            "try{document.documentElement.style.zoom='${clamped.toStringAsFixed(2)}';"
            "document.body.style.zoom='${clamped.toStringAsFixed(2)}';}catch(e){}",
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final frameRadius = widget.frameBorderRadius;
    final screenRadius = widget.screenBorderRadius;
    final hasStatusBar = widget.showStatusBar;

    final available = widget.height != null
        ? (widget.height! - widget.padding.vertical)
        : null;
    final effectiveWebViewHeight = available != null
        ? (available - (hasStatusBar ? widget.statusBarHeight : 0)).clamp(
            160.0,
            99999.0,
          )
        : widget.webViewHeight;

    final gestureRecognizers = widget.allowParentVerticalScroll
        ? <Factory<OneSequenceGestureRecognizer>>{
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            Factory<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(),
            ),
            Factory<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
            ),
            Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
          }
        : null;

    return Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090B) : const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(frameRadius),
        border: Border.all(
          color: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.14),
            colorScheme.outlineVariant,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameRadius),
        child: Stack(
          children: [
            if (_isLoading && _hasUrl)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glareController,
                  builder: (context, _) {
                    final t = _glareController.value;
                    final glare = colorScheme.primary.withValues(
                      alpha: isDark ? (0.10 + 0.10 * t) : (0.08 + 0.08 * t),
                    );
                    return IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1 + 2 * t, -1),
                            end: Alignment(0 + 2 * t, 1),
                            colors: [
                              Colors.transparent,
                              glare,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Column(
              children: [
                // Phone Status Bar
                if (hasStatusBar)
                  SizedBox(
                    height: widget.statusBarHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '9:41',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.signal_cellular_4_bar,
                                color: Colors.white.withValues(alpha: 0.92),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.wifi,
                                color: Colors.white.withValues(alpha: 0.92),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.battery_full,
                                color: Colors.white.withValues(alpha: 0.92),
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // WebView Container
                Stack(
                  children: [
                    Container(
                      height: effectiveWebViewHeight,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(screenRadius),
                      ),
                      child: _hasUrl
                          ? (_hasError
                                ? _buildErrorState(context)
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeIn,
                                    child: InAppWebView(
                                      key: ValueKey(widget.url),
                                      contextMenu: ContextMenu(),
                                      initialUrlRequest: URLRequest(
                                        url: WebUri(widget.url!.trim()),
                                      ),
                                      gestureRecognizers: gestureRecognizers,
                                      onWebViewCreated: _onWebViewCreated,
                                      onLoadStart: _onLoadStart,
                                      onLoadStop: _onLoadStop,
                                      onProgressChanged: _onProgressChanged,
                                    ),
                                  ))
                          : _buildNoPreviewState(context),
                    ),
                    if (_hasUrl)
                      Positioned(
                        left: 10,
                        right: 10,
                        top: 8,
                        child: AnimatedOpacity(
                          opacity: _isLoading ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _isLoading ? _progress : null,
                              minHeight: 3,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.08,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPreviewState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.web_asset_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No preview available',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This post has no live demo link',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load preview',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The app may not be deployed yet or the URL is invalid',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
