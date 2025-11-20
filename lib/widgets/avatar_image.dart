import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 通用头像显示组件
/// 自动检测 SVG 和普通图片格式
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

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(size / 2);

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
                    placeholderBuilder: (context) => _buildPlaceholder(),
                  );
                }
                return _buildPlaceholder();
              },
            )
          : Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: fit,
              excludeFromSemantics: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildPlaceholder();
              },
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            ),
    );
  }

  /// 加载并清理 SVG 数据，移除不支持的标签
  Future<String> _loadAndCleanSvg(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String svgContent = utf8.decode(response.bodyBytes);

        // 清理 SVG 中不支持的标签和属性
        svgContent = _cleanSvg(svgContent);

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

  Widget _buildPlaceholder() {
    if (placeholderText != null && placeholderText!.isNotEmpty) {
      final initial = placeholderText![0].toUpperCase();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade100,
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey.shade400,
      ),
    );
  }
}
