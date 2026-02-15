import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FloatingPreviewDock extends StatefulWidget {
  final String previewUrl;
  final int reloadVersion;
  final double topDock;

  const FloatingPreviewDock({
    super.key,
    required this.previewUrl,
    required this.reloadVersion,
    this.topDock = 8,
  });

  @override
  State<FloatingPreviewDock> createState() => _FloatingPreviewDockState();
}

class _FloatingPreviewDockState extends State<FloatingPreviewDock> {
  static const double _margin = 12;

  InAppWebViewController? _miniController;
  Offset? _position;
  Size _lastBounds = Size.zero;
  bool _hasAutoPlaced = false;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant FloatingPreviewDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.previewUrl.trim();
    final nextUrl = widget.previewUrl.trim();
    if (oldUrl != nextUrl) {
      _hasAutoPlaced = false;
    }
    if (oldWidget.reloadVersion != widget.reloadVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _miniController?.reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.previewUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        if (bounds.width <= 0 || bounds.height <= 0) {
          return const SizedBox.shrink();
        }

        final miniWidth = _dockWidth(bounds.width);
        final miniHeight = _dockHeight(bounds.width);
        final dockSize = Size(miniWidth, miniHeight);
        _ensurePosition(bounds, dockSize);

        final left = (_position?.dx ?? _margin).clamp(
          _margin,
          math.max(_margin, bounds.width - miniWidth - _margin),
        );
        final top = (_position?.dy ?? widget.topDock).clamp(
          _dockTop(bounds, dockSize),
          math.max(
            _dockTop(bounds, dockSize),
            bounds.height - miniHeight - _margin,
          ),
        );

        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: left.toDouble(),
              top: top.toDouble(),
              child: _buildDockCard(context, bounds, dockSize, url),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDockCard(
    BuildContext context,
    Size bounds,
    Size dockSize,
    String url,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _dragging = true;
      },
      onPanUpdate: (details) {
        final current = _position ?? _defaultPosition(bounds, dockSize);
        setState(() {
          _position = _clampOffset(current + details.delta, bounds, dockSize);
        });
      },
      onPanEnd: (_) {
        _snapToNearestAnchor(bounds, dockSize);
        _dragging = false;
      },
      onTap: () {
        if (_dragging) return;
        _openExpandedPreview(context, url);
      },
      child: SizedBox(
        width: dockSize.width,
        height: dockSize.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.82 : 0.92,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: true,
                  child: InAppWebView(
                    key: ValueKey('mini-preview-$url'),
                    contextMenu: ContextMenu(),
                    initialUrlRequest: URLRequest(url: WebUri(url)),
                    onWebViewCreated: (controller) {
                      _miniController = controller;
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colorScheme.surface.withValues(
                            alpha: isDark ? 0.58 : 0.42,
                          ),
                          colorScheme.surface.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 8,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_full_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CornerAccentPainter(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.82 : 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExpandedPreview(BuildContext context, String url) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return _PreviewExpandedDialog(
          previewUrl: url,
          reloadVersion: widget.reloadVersion,
        );
      },
    );
  }

  double _dockWidth(double viewportWidth) {
    if (viewportWidth < 420) return 168;
    if (viewportWidth < 768) return 188;
    return 212;
  }

  double _dockHeight(double viewportWidth) {
    if (viewportWidth < 420) return 126;
    if (viewportWidth < 768) return 138;
    return 152;
  }

  void _ensurePosition(Size bounds, Size dockSize) {
    if (_position == null || !_hasAutoPlaced) {
      _position = _defaultPosition(bounds, dockSize);
      _lastBounds = bounds;
      _hasAutoPlaced = true;
      return;
    }
    if (_lastBounds == bounds) return;
    _position = _clampOffset(_position!, bounds, dockSize);
    _lastBounds = bounds;
  }

  Offset _defaultPosition(Size bounds, Size dockSize) {
    final rightX = math.max(_margin, bounds.width - dockSize.width - _margin);
    return Offset(rightX, _dockTop(bounds, dockSize));
  }

  double _dockTop(Size bounds, Size dockSize) {
    final maxTop = math.max(_margin, bounds.height - dockSize.height - _margin);
    return widget.topDock.clamp(_margin, maxTop).toDouble();
  }

  Offset _clampOffset(Offset next, Size bounds, Size dockSize) {
    final minX = _margin;
    final maxX = math.max(_margin, bounds.width - dockSize.width - _margin);
    final minY = _dockTop(bounds, dockSize);
    final maxY = math.max(minY, bounds.height - dockSize.height - _margin);
    return Offset(
      next.dx.clamp(minX, maxX).toDouble(),
      next.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _snapToNearestAnchor(Size bounds, Size dockSize) {
    final current = _clampOffset(
      _position ?? _defaultPosition(bounds, dockSize),
      bounds,
      dockSize,
    );
    final top = _dockTop(bounds, dockSize);
    final rightX = math.max(_margin, bounds.width - dockSize.width - _margin);
    final centerX = math.max(_margin, (bounds.width - dockSize.width) / 2);
    final anchors = <Offset>[
      Offset(_margin, current.dy),
      Offset(rightX, current.dy),
      Offset(_margin, top),
      Offset(rightX, top),
      Offset(centerX, top),
    ];

    Offset target = anchors.first;
    var best = double.infinity;
    for (final anchor in anchors) {
      final dx = anchor.dx - current.dx;
      final dy = anchor.dy - current.dy;
      final dist = dx * dx + dy * dy;
      if (dist < best) {
        best = dist;
        target = anchor;
      }
    }
    setState(() {
      _position = _clampOffset(target, bounds, dockSize);
    });
  }
}

class _PreviewExpandedDialog extends StatefulWidget {
  final String previewUrl;
  final int reloadVersion;

  const _PreviewExpandedDialog({
    required this.previewUrl,
    required this.reloadVersion,
  });

  @override
  State<_PreviewExpandedDialog> createState() => _PreviewExpandedDialogState();
}

class _PreviewExpandedDialogState extends State<_PreviewExpandedDialog> {
  InAppWebViewController? _controller;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxWidth = math.min(size.width - 24, 980.0);
    final maxHeight = math.min(size.height - 40, size.height * 0.8);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.7 : 0.9,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.web_asset_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live Preview',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => _controller?.reload(),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InAppWebView(
                  key: ValueKey(
                    'expanded-preview-${widget.previewUrl}-${widget.reloadVersion}',
                  ),
                  contextMenu: ContextMenu(),
                  initialUrlRequest: URLRequest(url: WebUri(widget.previewUrl)),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStart: (controller, url) {
                    if (!mounted) return;
                    setState(() => _isLoading = true);
                  },
                  onLoadStop: (controller, url) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerAccentPainter extends CustomPainter {
  final Color color;

  const _CornerAccentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const len = 12.0;
    const gap = 6.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      const Offset(gap, gap),
      const Offset(gap + len, gap),
      paint,
    );
    canvas.drawLine(
      const Offset(gap, gap),
      const Offset(gap, gap + len),
      paint,
    );
    // Top-right
    canvas.drawLine(
      Offset(size.width - gap, gap),
      Offset(size.width - gap - len, gap),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - gap, gap),
      Offset(size.width - gap, gap + len),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(gap, size.height - gap),
      Offset(gap + len, size.height - gap),
      paint,
    );
    canvas.drawLine(
      Offset(gap, size.height - gap),
      Offset(gap, size.height - gap - len),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - gap, size.height - gap),
      Offset(size.width - gap - len, size.height - gap),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - gap, size.height - gap),
      Offset(size.width - gap, size.height - gap - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerAccentPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
