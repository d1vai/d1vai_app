import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// SVG 缓存服务
/// 负责 SVG 图片的本地磁盘缓存管理
class SvgCacheService {
  static final SvgCacheService _instance = SvgCacheService._internal();
  factory SvgCacheService() => _instance;
  SvgCacheService._internal();

  Directory? _cacheDir;

  /// 初始化缓存目录
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/svg_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    debugPrint('SVG 缓存目录: ${_cacheDir!.path}');
  }

  /// 根据 URL 生成缓存文件名
  String _getCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return '$digest.svg';
  }

  /// 从缓存读取 SVG
  Future<String?> get(String url) async {
    try {
      if (_cacheDir == null) await init();

      final fileName = _getCacheFileName(url);
      final file = File('${_cacheDir!.path}/$fileName');

      if (await file.exists()) {
        final content = await file.readAsString();
        debugPrint('从磁盘缓存读取 SVG: $url');
        return content;
      }
    } catch (e) {
      debugPrint('读取 SVG 缓存失败: $e');
    }

    return null;
  }

  /// 保存 SVG 到缓存
  Future<void> put(String url, String svgContent) async {
    try {
      if (_cacheDir == null) await init();

      final fileName = _getCacheFileName(url);
      final file = File('${_cacheDir!.path}/$fileName');

      await file.writeAsString(svgContent);
      debugPrint('SVG 已保存到磁盘缓存: $url');
    } catch (e) {
      debugPrint('保存 SVG 缓存失败: $e');
    }
  }

  /// 删除指定 URL 的缓存
  Future<void> delete(String url) async {
    try {
      if (_cacheDir == null) await init();

      final fileName = _getCacheFileName(url);
      final file = File('${_cacheDir!.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        debugPrint('已删除 SVG 缓存: $url');
      }
    } catch (e) {
      debugPrint('删除 SVG 缓存失败: $e');
    }
  }

  /// 清空所有缓存
  Future<void> clear() async {
    try {
      if (_cacheDir == null) await init();

      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        debugPrint('已清空所有 SVG 缓存');
      }
    } catch (e) {
      debugPrint('清空 SVG 缓存失败: $e');
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      if (_cacheDir == null) await init();

      int totalSize = 0;

      if (await _cacheDir!.exists()) {
        await for (var entity in _cacheDir!.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('获取缓存大小失败: $e');
      return 0;
    }
  }
}
