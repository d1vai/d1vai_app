import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/svg_cache_service.dart';

/// 通用头像显示组件
/// 自动检测 SVG 和普通图片格式，并支持缓存
class AvatarImage extends StatefulWidget {
  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final String? placeholderText;
  final bool showBorder;
  final double borderWidth;
  final Color? borderColor;

  const AvatarImage({
    super.key,
    required this.imageUrl,
    this.size = 50,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholderText,
    this.showBorder = true,
    this.borderWidth = 1,
    this.borderColor,
  });

  // SVG 缓存服务
  static final _svgCache = SvgCacheService();

  /// 清除指定 URL 的缓存（用户更新头像时调用）
  static Future<void> clearCache(String url) async {
    // 清除 SVG 缓存
    if (url.contains('.svg') || url.contains('/svg')) {
      await _svgCache.delete(url);
    }

    // 清除 CachedNetworkImage 缓存
    if (!url.contains('.svg') && !url.contains('/svg')) {
      await CachedNetworkImage.evictFromCache(url);
    }
  }

  /// 清除所有头像缓存
  static Future<void> clearAllCache() async {
    await _svgCache.clear();
  }

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  Future<String>? _svgFuture;
  bool _isSvg = false;

  @override
  void initState() {
    super.initState();
    _recomputeSvgState();
  }

  @override
  void didUpdateWidget(covariant AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _recomputeSvgState();
    }
  }

  void _recomputeSvgState() {
    final isValidHttpUrl = _isValidHttpUrl(widget.imageUrl);
    _isSvg = isValidHttpUrl &&
        (widget.imageUrl.contains('.svg') || widget.imageUrl.contains('/svg'));
    _svgFuture = _isSvg ? _loadAndCleanSvg(widget.imageUrl) : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.size / 2);

    final isValidHttpUrl = _isValidHttpUrl(widget.imageUrl);

    final border = widget.showBorder
        ? Border.all(
            color: widget.borderColor ??
                colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: widget.borderWidth,
          )
        : null;

    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: effectiveBorderRadius,
        border: border,
      ),
      child: _isSvg
          ? FutureBuilder<String>(
              future: _svgFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.trim().isNotEmpty) {
                  return SvgPicture.string(
                    snapshot.data!,
                    fit: widget.fit,
                    excludeFromSemantics: true,
                    placeholderBuilder: (context) => _buildPlaceholder(context),
                  );
                }
                return _buildPlaceholder(context);
              },
            )
          : (isValidHttpUrl
              ? CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  width: widget.size,
                  height: widget.size,
                  fit: widget.fit,
                  placeholder: (context, url) => _buildPlaceholder(context),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(context),
                )
              : _buildPlaceholder(context)),
    );
  }

  /// 加载并清理 SVG 数据，带磁盘缓存支持
  Future<String> _loadAndCleanSvg(String url) async {
    // 1. 先检查磁盘缓存
    final cachedContent = await AvatarImage._svgCache.get(url);
    if (cachedContent != null) {
      return cachedContent;
    }

    // 2. 从网络加载
    try {
      if (kDebugMode) {
        debugPrint('从网络加载 SVG: $url');
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String svgContent = utf8.decode(response.bodyBytes);

        // 清理 SVG 中不支持的标签和属性
        svgContent = _cleanSvg(svgContent);

        // 3. 存入磁盘缓存
        await AvatarImage._svgCache.put(url, svgContent);

        return svgContent;
      }
    } catch (e) {
      // 静默处理错误，返回空 SVG
      if (kDebugMode) {
        debugPrint('SVG 加载失败: $e');
      }
    }

    // 返回简单的空 SVG
    return '<svg xmlns="http://www.w3.org/2000/svg" width="${widget.size}" height="${widget.size}"></svg>';
  }

  /// 清理 SVG 内容，移除可能导致警告的标签
  String _cleanSvg(String svg) {
    // 移除 <metadata> 标签及其内容
    svg = svg.replaceAllMapped(
      RegExp(r'<metadata[^>]*>[\s\S]*?</metadata>', caseSensitive: false),
      (match) => '',
    );

    // 移除 <desc> 和 <title> 标签（这些可能导致警告）
    svg = svg.replaceAllMapped(
      RegExp(r'<(desc|title)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      (match) => '',
    );

    // 清理 xmlns:xlink 属性（如果存在）
    svg = svg.replaceAll('xmlns:xlink="http://www.w3.org/1999/xlink"', '');

    return svg;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.size / 2);
    if (widget.placeholderText != null && widget.placeholderText!.isNotEmpty) {
      final initial = widget.placeholderText![0].toUpperCase();
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surfaceContainerHighest,
          ),
          borderRadius: effectiveBorderRadius,
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: effectiveBorderRadius,
      ),
      child: Icon(
        Icons.person,
        size: widget.size * 0.5,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }

  bool _isValidHttpUrl(String url) {
    final u = url.trim();
    if (u.isEmpty || u == 'placeholder') return false;
    final uri = Uri.tryParse(u);
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
