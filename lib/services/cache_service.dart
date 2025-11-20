import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存条目类
class CacheEntry {
  final String data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > ttl;
  }

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'ttl': ttl.inMilliseconds,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    data: json['data'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    ttl: Duration(milliseconds: json['ttl'] as int),
  );
}

/// 通用的缓存服务
/// 支持内存缓存和磁盘缓存（通过 SharedPreferences）
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // 内存缓存
  final Map<String, CacheEntry> _memoryCache = {};

  /// 从缓存获取数据
  /// 返回 null 如果缓存不存在或已过期
  Future<T?> get<T>(String key, T Function(Map<String, dynamic>) fromJsonT) async {
    // 首先检查内存缓存
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (!entry.isExpired) {
        try {
          final json = jsonDecode(entry.data) as Map<String, dynamic>;
          return fromJsonT(json);
        } catch (e) {
          debugPrint('Cache decode error for key $key: $e');
          _remove(key);
        }
      } else {
        _remove(key);
      }
    }

    // 尝试从磁盘缓存加载
    return await _loadFromDisk<T>(key, fromJsonT);
  }

  /// 设置缓存数据
  Future<bool> set<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJsonT, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    try {
      final json = toJsonT(data);
      final jsonString = jsonEncode(json);
      final entry = CacheEntry(
        data: jsonString,
        timestamp: DateTime.now(),
        ttl: ttl,
      );

      // 保存到内存缓存
      _memoryCache[key] = entry;

      // 保存到磁盘缓存
      return await _saveToDisk(key, entry);
    } catch (e) {
      debugPrint('Cache save error for key $key: $e');
      return false;
    }
  }

  /// 移除缓存
  void _remove(String key) {
    _memoryCache.remove(key);
    _removeFromDisk(key);
  }

  /// 清空所有缓存
  Future<void> clear() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('cache_')) {
        await prefs.remove(key);
      }
    }
  }

  /// 从磁盘加载缓存
  Future<T?> _loadFromDisk<T>(String key, T Function(Map<String, dynamic>) fromJsonT) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cache_$key';
      final jsonString = prefs.getString(cacheKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(json);

      if (!entry.isExpired) {
        // 重新添加到内存缓存
        _memoryCache[key] = entry;
        // entry.data 已经是 JSON 字符串
        return fromJsonT(jsonDecode(entry.data) as Map<String, dynamic>);
      } else {
        // 已过期，删除
        await prefs.remove(cacheKey);
        return null;
      }
    } catch (e) {
      debugPrint('Cache load error for key $key: $e');
      return null;
    }
  }

  /// 保存缓存到磁盘
  Future<bool> _saveToDisk(String key, CacheEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cache_$key';
      final jsonString = jsonEncode(entry.toJson());
      return await prefs.setString(cacheKey, jsonString);
    } catch (e) {
      debugPrint('Cache save disk error for key $key: $e');
      return false;
    }
  }

  /// 从磁盘删除缓存
  Future<void> _removeFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cache_$key';
      await prefs.remove(cacheKey);
    } catch (e) {
      debugPrint('Cache remove disk error for key $key: $e');
    }
  }

  /// 清理过期的内存缓存
  void cleanExpiredMemoryCache() {
    final expiredKeys = <String>[];
    _memoryCache.forEach((key, entry) {
      if (entry.isExpired) {
        expiredKeys.add(key);
      }
    });
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }
  }

  /// 失效指定的缓存键
  void invalidate(String key) {
    _remove(key);
  }

  /// 清除社区相关缓存
  Future<void> clearCommunityCache() async {
    final keysToRemove = <String>[];
    _memoryCache.forEach((key, _) {
      if (key.startsWith('community_posts_')) {
        keysToRemove.add(key);
      }
    });
    for (final key in keysToRemove) {
      _remove(key);
    }

    // 清除磁盘上的社区缓存
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('cache_community_posts_')) {
        await prefs.remove(key);
      }
    }
  }

  /// 清除项目相关缓存
  void invalidateProjectsCache() {
    invalidate('user_projects');
  }

  /// 清除用户相关缓存
  void invalidateUserCache() {
    invalidate('user_profile');
  }
}
