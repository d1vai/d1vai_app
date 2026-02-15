import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 图片压缩工具类
/// 支持质量压缩和尺寸压缩
class ImageCompressor {
  /// 压缩图片
  /// [imageBytes] 原始图片字节数据
  /// [quality] 压缩质量（0.1-1.0），默认 0.8
  /// [maxWidth] 最大宽度，默认 800
  /// [maxHeight] 最大高度，默认 800
  /// 返回压缩后的字节数据
  static Future<Uint8List> compress({
    required Uint8List imageBytes,
    double quality = 0.8,
    int maxWidth = 800,
    int maxHeight = 800,
  }) async {
    try {
      // 如果是 Web 平台，直接返回原始数据（简化处理）
      if (kIsWeb) {
        return imageBytes;
      }

      // 解码图片
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageBytes;
      }

      // 计算新尺寸
      int newWidth = image.width;
      int newHeight = image.height;

      // 如果图片太大，进行尺寸压缩
      if (image.width > maxWidth || image.height > maxHeight) {
        final ratio =
            (image.width / maxWidth).compareTo(image.height / maxHeight) > 0
            ? maxWidth / image.width
            : maxHeight / image.height;
        newWidth = (image.width * ratio).round();
        newHeight = (image.height * ratio).round();
      }

      // 如果尺寸不变，只进行质量压缩
      if (newWidth == image.width && newHeight == image.height) {
        return _compressQuality(imageBytes, quality);
      }

      // 调整尺寸
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // 质量压缩
      return Uint8List.fromList(
        img.encodeJpg(resized, quality: (quality * 100).round()),
      );
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return imageBytes;
    }
  }

  /// 仅进行质量压缩
  static Uint8List _compressQuality(Uint8List imageBytes, double quality) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return imageBytes;
    }
    return Uint8List.fromList(
      img.encodeJpg(image, quality: (quality * 100).round()),
    );
  }

  /// 获取图片信息
  static Map<String, dynamic> getImageInfo(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return {'width': 0, 'height': 0, 'size': imageBytes.length};
    }
    return {
      'width': image.width,
      'height': image.height,
      'size': imageBytes.length,
      'format': 'JPEG',
    };
  }

  /// 计算压缩率
  static double getCompressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return 0;
    return (originalSize - compressedSize) / originalSize;
  }
}
