import 'package:flutter/material.dart';
import '../widgets/snackbar_helper.dart';

/// 存储和缓存管理页面
///
/// 提供以下功能：
/// - 查看存储使用情况
/// - 清除应用缓存
/// - 选择性清除特定类型的缓存
/// - 自动清理设置
class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  // 存储使用情况
  int _totalCacheSize = 0;
  int _chatCacheSize = 0;
  int _imageCacheSize = 0;
  int _tempFileSize = 0;

  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  /// 加载存储信息
  Future<void> _loadStorageInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 模拟加载存储使用情况
      // 在真实应用中，这里会扫描实际的缓存目录
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        // 模拟数据：单位为字节
        _totalCacheSize = 45 * 1024 * 1024; // 45 MB
        _chatCacheSize = 25 * 1024 * 1024; // 25 MB
        _imageCacheSize = 15 * 1024 * 1024; // 15 MB
        _tempFileSize = 5 * 1024 * 1024; // 5 MB
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to load storage info: $e',
      );
    }
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 清除全部缓存
  Future<void> _clearAllCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text(
          'Are you sure you want to clear all cache? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isClearing = true;
    });

    try {
      // 模拟清除过程
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _totalCacheSize = 0;
        _chatCacheSize = 0;
        _imageCacheSize = 0;
        _tempFileSize = 0;
        _isClearing = false;
      });

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'All cache cleared successfully',
      );
    } catch (e) {
      setState(() {
        _isClearing = false;
      });
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to clear cache: $e',
      );
    }
  }

  /// 清除特定类型的缓存
  Future<void> _clearCacheType(String type) async {
    String cacheName = '';
    int cacheSize = 0;

    switch (type) {
      case 'chat':
        cacheName = 'Chat History';
        cacheSize = _chatCacheSize;
        break;
      case 'image':
        cacheName = 'Image Cache';
        cacheSize = _imageCacheSize;
        break;
      case 'temp':
        cacheName = 'Temporary Files';
        cacheSize = _tempFileSize;
        break;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $cacheName'),
        content: Text(
          'Are you sure you want to clear $cacheName '
          '(${_formatBytes(cacheSize)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isClearing = true;
    });

    try {
      // 模拟清除过程
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        switch (type) {
          case 'chat':
            _chatCacheSize = 0;
            break;
          case 'image':
            _imageCacheSize = 0;
            break;
          case 'temp':
            _tempFileSize = 0;
            break;
        }
        _totalCacheSize = _chatCacheSize + _imageCacheSize + _tempFileSize;
        _isClearing = false;
      });

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: '$cacheName cleared successfully',
      );
    } catch (e) {
      setState(() {
        _isClearing = false;
      });
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to clear cache: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage & Cache'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStorageInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStorageOverviewCard(),
                const SizedBox(height: 24),
                _buildCacheManagementCard(),
                const SizedBox(height: 24),
                _buildClearAllButton(),
              ],
            ),
    );
  }

  /// 构建存储概览卡片
  Widget _buildStorageOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Storage Usage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 总存储使用情况
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.deepPurple.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Cache Size',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatBytes(_totalCacheSize),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.delete_sweep,
                    size: 40,
                    color: Colors.deepPurple.shade300,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建缓存管理卡片
  Widget _buildCacheManagementCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble),
            title: const Text('Chat History'),
            subtitle: Text(_formatBytes(_chatCacheSize)),
            trailing: _chatCacheSize > 0
                ? TextButton(
                    onPressed: _isClearing ? null : () => _clearCacheType('chat'),
                    child: const Text('Clear'),
                  )
                : const Text('Clean', style: TextStyle(color: Colors.grey)),
            onTap: _chatCacheSize > 0
                ? () => _clearCacheType('chat')
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image Cache'),
            subtitle: Text(_formatBytes(_imageCacheSize)),
            trailing: _imageCacheSize > 0
                ? TextButton(
                    onPressed: _isClearing ? null : () => _clearCacheType('image'),
                    child: const Text('Clear'),
                  )
                : const Text('Clean', style: TextStyle(color: Colors.grey)),
            onTap: _imageCacheSize > 0
                ? () => _clearCacheType('image')
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Temporary Files'),
            subtitle: Text(_formatBytes(_tempFileSize)),
            trailing: _tempFileSize > 0
                ? TextButton(
                    onPressed: _isClearing ? null : () => _clearCacheType('temp'),
                    child: const Text('Clear'),
                  )
                : const Text('Clean', style: TextStyle(color: Colors.grey)),
            onTap: _tempFileSize > 0
                ? () => _clearCacheType('temp')
                : null,
          ),
        ],
      ),
    );
  }

  /// 构建清除全部按钮
  Widget _buildClearAllButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isClearing || _totalCacheSize == 0
            ? null
            : _clearAllCache,
        icon: _isClearing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.delete_sweep),
        label: Text(_isClearing ? 'Clearing...' : 'Clear All Cache'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
