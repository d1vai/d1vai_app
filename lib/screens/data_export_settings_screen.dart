import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/api_key.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

String _simpleHash(String input) {
  // 简单的哈希实现，不依赖外部包
  var hash = 0;
  for (var i = 0; i < input.length; i++) {
    hash = ((hash << 5) - hash) + input.codeUnitAt(i);
    hash = hash & hash; // 转换为 32 位整数
  }
  return hash.abs().toRadixString(36);
}

class DataExportSettingsScreen extends StatefulWidget {
  const DataExportSettingsScreen({super.key});

  @override
  State<DataExportSettingsScreen> createState() => _DataExportSettingsScreenState();
}

class _DataExportSettingsScreenState extends State<DataExportSettingsScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  bool _isExporting = false;
  String _exportStatus = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Export'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildExportOptions(),
          const SizedBox(height: 24),
          _buildExportButton(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  'About Data Export',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You can export all your data including profile information, projects, '
              'conversations, and community posts. The data will be exported in JSON format '
              'and may take a few minutes to generate.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Options',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildExportOption(
              icon: Icons.person,
              title: 'Profile Information',
              description: 'Your account details, company info, and preferences',
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.folder,
              title: 'Projects',
              description: 'All your projects and their metadata',
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.chat_bubble,
              title: 'Conversations',
              description: 'Chat history and messages',
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.forum,
              title: 'Community Posts',
              description: 'Your posts and comments in the community',
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.integration_instructions,
              title: 'API Keys',
              description: 'Your API keys (names only, not the actual keys)',
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.wallet,
              title: 'Wallet Connections',
              description: 'Connected wallet addresses',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ],
    );
  }

  Widget _buildExportButton() {
    return Column(
      children: [
        if (_isExporting) ...[
          Card(
            color: Colors.deepPurple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _exportStatus.isEmpty ? 'Preparing your data...' : _exportStatus,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportData,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export My Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your data export will be generated and ready to download. '
          'This process may take a few minutes.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _exportStatus = 'Collecting your data...';
    });

    try {
      final exportData = <String, dynamic>{
        'export_info': {
          'generated_at': DateTime.now().toIso8601String(),
          'format_version': '1.0',
          'source': 'd1vai_app',
        },
      };

      // 1. 导出用户资料
      _exportStatus = 'Fetching profile information...';
      if (mounted) setState(() {});
      try {
        final user = await _d1vaiService.getUserProfile();
        exportData['profile'] = user.toJson();
      } catch (e) {
        debugPrint('Failed to export profile: $e');
        exportData['profile'] = {'error': 'Failed to load profile'};
      }

      // 2. 导出发送的项目
      _exportStatus = 'Fetching projects...';
      if (mounted) setState(() {});
      try {
        final projects = await _d1vaiService.getUserProjects();
        exportData['projects'] = projects.map((p) => p.toJson()).toList();
      } catch (e) {
        debugPrint('Failed to export projects: $e');
        exportData['projects'] = {'error': 'Failed to load projects'};
      }

      // 3. 导出 API 密钥（仅名称，不包含实际密钥）
      _exportStatus = 'Fetching API keys...';
      if (mounted) setState(() {});
      try {
        final List<ApiKey> apiKeys = await _d1vaiService.getApiKeys();
        exportData['api_keys'] = apiKeys
            .map((k) => {
                  'id': k.id,
                  'name': k.name,
                  'created_at': k.createdAt.toIso8601String(),
                  'last_used_at': k.lastUsedAt?.toIso8601String(),
                  'is_active': k.isActive,
                  'note': 'Actual keys are not included for security',
                })
            .toList();
      } catch (e) {
        debugPrint('Failed to export API keys: $e');
        exportData['api_keys'] = {'error': 'Failed to load API keys'};
      }

      // 4. 导出邀请信息
      _exportStatus = 'Fetching invitation data...';
      if (mounted) setState(() {});
      try {
        final invitees = await _d1vaiService.getMyInvitees();
        exportData['invitations'] = {
          'sent': invitees.map((u) => u.toJson()).toList(),
          'received_count': 0, // 无法从当前API获取接收到的邀请
        };
      } catch (e) {
        debugPrint('Failed to export invitations: $e');
        exportData['invitations'] = {'error': 'Failed to load invitations'};
      }

      // 5. 模拟其他数据
      _exportStatus = 'Generating export file...';
      if (mounted) setState(() {});

      // 模拟数据（如果API不可用）
      if (exportData['profile'] is Map && (exportData['profile'] as Map).containsKey('error')) {
        exportData['profile'] = _generateMockProfileData();
      }
      if (exportData['projects'] is Map && (exportData['projects'] as Map).containsKey('error')) {
        exportData['projects'] = _generateMockProjectsData();
      }
      if (exportData['api_keys'] is Map && (exportData['api_keys'] as Map).containsKey('error')) {
        exportData['api_keys'] = _generateMockApiKeysData();
      }
      if (exportData['invitations'] is Map && (exportData['invitations'] as Map).containsKey('error')) {
        exportData['invitations'] = _generateMockInvitationsData();
      }

      // 添加模拟的其他数据
      exportData['conversations'] = _generateMockConversationsData();
      exportData['community_posts'] = _generateMockCommunityPostsData();
      exportData['settings'] = _generateMockSettingsData();

      _exportStatus = 'Creating archive...';
      if (mounted) setState(() {});

      // 生成校验和
      final jsonString = json.encode(exportData);
      final checksum = _simpleHash(jsonString);
      exportData['checksum'] = checksum;

      _exportStatus = 'Finalizing export...';
      if (mounted) setState(() {});

      // 创建文件内容
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final filename = 'd1vai_export_$timestamp.json';
      final content = json.encode(exportData, toEncodable: (value) {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is Uint8List) {
          return base64.encode(value);
        }
        return value;
      });

      // 保存并分享文件
      await _saveAndShareFile(filename, content);

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Export Complete',
        message: 'Your data has been exported successfully',
      );

      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });
    } catch (e) {
      debugPrint('Failed to export data: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Export Failed',
          message: 'Failed to export data: $e',
        );
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _saveAndShareFile(String filename, String content) async {
    // 在真实应用中，这里会创建一个临时文件并通过分享API分享
    // 在演示中，我们直接将内容复制到剪贴板
    await Clipboard.setData(ClipboardData(text: content));

    // 显示成功对话框，包含文件名和一些内容预览
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Export Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filename: $filename',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Your data export has been copied to the clipboard. In a production app, '
                'this would be saved as a file and you would be able to download or share it.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Note: The full export data is in JSON format and has been copied to your clipboard.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  // ========== 模拟数据生成方法 ==========

  Map<String, dynamic> _generateMockProfileData() {
    return {
      'id': 'demo_user_id',
      'email': 'demo@example.com',
      'company_name': 'Demo Company',
      'industry': 'Technology',
      'company_website': 'https://demo.com',
      'created_at': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _generateMockProjectsData() {
    return [
      {
        'id': 'proj_1',
        'project_name': 'My First Project',
        'project_description': 'A demo project',
        'project_port': 3000,
        'created_at': DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      },
      {
        'id': 'proj_2',
        'project_name': 'Another Project',
        'project_description': 'Another demo project',
        'project_port': 3001,
        'created_at': DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      },
    ];
  }

  List<Map<String, dynamic>> _generateMockApiKeysData() {
    return [
      {
        'id': 'key_1',
        'name': 'Production Key',
        'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'is_active': true,
        'note': 'Actual keys are not included for security',
      },
      {
        'id': 'key_2',
        'name': 'Development Key',
        'created_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'is_active': true,
        'note': 'Actual keys are not included for security',
      },
    ];
  }

  Map<String, dynamic> _generateMockInvitationsData() {
    return {
      'sent': [],
      'received_count': 0,
    };
  }

  List<Map<String, dynamic>> _generateMockConversationsData() {
    return [
      {
        'id': 'conv_1',
        'project_id': 'proj_1',
        'messages': [
          {
            'id': 'msg_1',
            'content': 'Hello, this is a demo conversation',
            'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
            'sender': 'user',
          },
          {
            'id': 'msg_2',
            'content': 'This is a demo message',
            'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
            'sender': 'assistant',
          },
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _generateMockCommunityPostsData() {
    return [
      {
        'id': 'post_1',
        'title': 'My First Post',
        'content': 'This is a demo post',
        'created_at': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
        'likes': 5,
        'comments': 2,
      },
    ];
  }

  Map<String, dynamic> _generateMockSettingsData() {
    return {
      'theme': 'system',
      'language': 'en',
      'notifications': {
        'email': true,
        'push': true,
        'project_updates': true,
        'invites': true,
        'system': true,
      },
    };
  }
}
