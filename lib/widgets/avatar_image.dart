import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/svg_cache_service.dart';

/// 通用头像显示组件
/// 自动检测 SVG 和普通图片格式，并支持缓存
class AvatarImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final String? placeholderText;

  const AvatarImage({
    super.key,
    required this.imageUrl,
    this.size = 50,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholderText,
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
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(size / 2);

    // 检查是否为 SVG URL
    final isSvg = imageUrl.contains('.svg') || imageUrl.contains('/svg');

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: isSvg
          ? FutureBuilder<String>(
              future: _loadAndCleanSvg(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return SvgPicture.string(
                    snapshot.data!,
                    width: size,
                    height: size,
                    fit: fit,
                    excludeFromSemantics: true,
                    placeholderBuilder: (context) => _buildPlaceholder(context),
                  );
                }
                return _buildPlaceholder(context);
              },
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: fit,
              placeholder: (context, url) => _buildPlaceholder(context),
              errorWidget: (context, url, error) => _buildPlaceholder(context),
              // 设置缓存图片尺寸
              maxWidthDiskCache: (size * 3).toInt(),
              maxHeightDiskCache: (size * 3).toInt(),
            ),
    );
  }

  /// 加载并清理 SVG 数据，带磁盘缓存支持
  Future<String> _loadAndCleanSvg(String url) async {
    // 1. 先检查磁盘缓存
    final cachedContent = await _svgCache.get(url);
    if (cachedContent != null) {
      return cachedContent;
    }

    // 2. 从网络加载
    try {
      debugPrint('从网络加载 SVG: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String svgContent = utf8.decode(response.bodyBytes);

        // 清理 SVG 中不支持的标签和属性
        svgContent = _cleanSvg(svgContent);

        // 3. 存入磁盘缓存
        await _svgCache.put(url, svgContent);

        return svgContent;
      }
    } catch (e) {
      // 静默处理错误，返回空 SVG
      debugPrint('SVG 加载失败: $e');
    }

    // 返回简单的空 SVG
    return '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size"></svg>';
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
    if (placeholderText != null && placeholderText!.isNotEmpty) {
      final initial = placeholderText![0].toUpperCase();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}
