import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          ? SvgPicture.network(
              imageUrl,
              width: size,
              height: size,
              fit: fit,
              placeholderBuilder: (context) => _buildPlaceholder(),
              // 忽略 SVG 中的 metadata 等不支持的标签
              allowDrawingOutsideViewBox: true,
            )
          : Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildPlaceholder();
              },
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            ),
    );
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
