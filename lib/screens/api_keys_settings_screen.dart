import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_key.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

class ApiKeysSettingsScreen extends StatefulWidget {
  const ApiKeysSettingsScreen({super.key});

  @override
  State<ApiKeysSettingsScreen> createState() => _ApiKeysSettingsScreenState();
}

class _ApiKeysSettingsScreenState extends State<ApiKeysSettingsScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  List<ApiKey> _apiKeys = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiKeys = await _d1vaiService.getApiKeys();
      if (mounted) {
        setState(() {
          _apiKeys = apiKeys;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load API keys: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load API keys: $e';
          _isLoading = false;
        });

        // 如果API不存在，使用模拟数据
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          _loadMockApiKeys();
        }
      }
    }
  }

  void _loadMockApiKeys() {
    // 模拟API数据 - 用于演示
    setState(() {
      _apiKeys = [
        ApiKey(
          id: '1',
          name: 'Production Key',
          key: 'sk-proj-abcdefghijklmnopqrstuvwxyz1234567890',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 2)),
          isActive: true,
        ),
        ApiKey(
          id: '2',
          name: 'Development Key',
          key: 'sk-dev-abcdefghijklmnopqrstuvwxyz1234567890',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
          isActive: true,
        ),
        ApiKey(
          id: '3',
          name: 'Testing Key',
          key: 'sk-test-abcdefghijklmnopqrstuvwxyz1234567890',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          isActive: false,
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _createApiKey() async {
    final nameController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your API key to identify it easily.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Key Name',
                hintText: 'e.g., Production, Development, Testing',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop({'name': name});
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final newKey = await _d1vaiService.createApiKey(result['name']!);
      if (mounted) {
        setState(() {
          _apiKeys.insert(0, newKey);
        });

        // 显示新密钥（只显示一次）
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('API Key Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your new API key:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    newKey.key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '⚠️ This key will only be shown once. Make sure to copy it now.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: newKey.key));
                  if (context.mounted) {
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Copied',
                      message: 'API key copied to clipboard',
                    );
                  }
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: const Text('Copy & Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to create API key: $e');
      if (mounted) {
        // 如果API不存在，使用模拟创建
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          _createMockApiKey(result['name']!);
        } else {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to create API key: $e',
          );
        }
      }
    }
  }

  void _createMockApiKey(String name) {
    final newKey = ApiKey(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      key: 'sk-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      createdAt: DateTime.now(),
      isActive: true,
    );

    setState(() {
      _apiKeys.insert(0, newKey);
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Created (Demo)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your new API key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                newKey.key,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ This is a demo. In production, the key will only be shown once.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: newKey.key));
              if (context.mounted) {
                SnackBarHelper.showSuccess(
                  context,
                  title: 'Copied',
                  message: 'API key copied to clipboard',
                );
              }
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
            child: const Text('Copy & Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteApiKey(ApiKey apiKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: Text(
          'Are you sure you want to delete "${apiKey.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _d1vaiService.deleteApiKey(apiKey.id);
      if (!mounted) return;
      setState(() {
        _apiKeys.removeWhere((k) => k.id == apiKey.id);
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'API key deleted successfully',
      );
    } catch (e) {
      debugPrint('Failed to delete API key: $e');
      if (mounted) {
        // 如果API不存在，使用模拟删除
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          setState(() {
            _apiKeys.removeWhere((k) => k.id == apiKey.id);
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'API key deleted successfully (demo)',
          );
        } else {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to delete API key: $e',
          );
        }
      }
    }
  }

  Future<void> _toggleApiKeyStatus(ApiKey apiKey) async {
    try {
      await _d1vaiService.updateApiKeyStatus(apiKey.id, !apiKey.isActive);
      if (!mounted) return;
      setState(() {
        final index = _apiKeys.indexWhere((k) => k.id == apiKey.id);
        if (index != -1) {
          _apiKeys[index] = apiKey.copyWith(isActive: !apiKey.isActive);
        }
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'API key ${!apiKey.isActive ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('Failed to update API key status: $e');
      if (mounted) {
        // 如果API不存在，使用模拟更新
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          setState(() {
            final index = _apiKeys.indexWhere((k) => k.id == apiKey.id);
            if (index != -1) {
              _apiKeys[index] = apiKey.copyWith(isActive: !apiKey.isActive);
            }
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'API key ${!apiKey.isActive ? 'enabled' : 'disabled'} (demo)',
          );
        } else {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to update API key: $e',
          );
        }
      }
    }
  }

  Future<void> _copyApiKey(ApiKey apiKey) async {
    await Clipboard.setData(ClipboardData(text: apiKey.key));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'API key copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApiKeys,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _apiKeys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadApiKeys,
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadMockApiKeys,
                        child: const Text('Load Demo Data'),
                      ),
                    ],
                  ),
                )
              : _apiKeys.isEmpty
                  ? _buildEmptyState()
                  : _buildApiKeysList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createApiKey,
        icon: const Icon(Icons.add),
        label: const Text('New Key'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vpn_key_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No API keys yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first API key to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _apiKeys.length,
      itemBuilder: (context, index) {
        final apiKey = _apiKeys[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apiKey.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            apiKey.maskedKey,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: apiKey.isActive,
                      onChanged: (_) => _toggleApiKeyStatus(apiKey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Created ${apiKey.createdAtAgo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (apiKey.lastUsedAgo != null)
                      Expanded(
                        child: Text(
                          'Last used ${apiKey.lastUsedAgo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => _copyApiKey(apiKey),
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy key',
                    ),
                    IconButton(
                      onPressed: () => _deleteApiKey(apiKey),
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'Delete key',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
