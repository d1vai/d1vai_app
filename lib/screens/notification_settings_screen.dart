import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/snackbar_helper.dart';

/// 通知设置页面
///
/// 提供各类通知的开关管理，包括：
/// - 邮件通知
/// - 推送通知
/// - 项目更新通知
/// - 邀请通知
/// - 系统公告
///
/// 使用 SharedPreferences 本地存储用户偏好
/// 后续可对接后端 API 同步设置
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // 通知开关状态
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _projectUpdates = true;
  bool _inviteNotifications = true;
  bool _systemAnnouncements = true;
  bool _marketingEmails = false;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 从本地存储加载通知设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _emailNotifications =
            prefs.getBool('notification_email') ?? true;
        _pushNotifications =
            prefs.getBool('notification_push') ?? true;
        _projectUpdates =
            prefs.getBool('notification_project_updates') ?? true;
        _inviteNotifications =
            prefs.getBool('notification_invites') ?? true;
        _systemAnnouncements =
            prefs.getBool('notification_system') ?? true;
        _marketingEmails =
            prefs.getBool('notification_marketing') ?? false;
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
        message: 'Failed to load notification settings',
      );
    }
  }

  /// 保存通知设置到本地存储
  /// 后续可扩展为调用后端 API
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_email', _emailNotifications);
      await prefs.setBool('notification_push', _pushNotifications);
      await prefs.setBool(
          'notification_project_updates', _projectUpdates);
      await prefs.setBool(
          'notification_invites', _inviteNotifications);
      await prefs.setBool('notification_system', _systemAnnouncements);
      await prefs.setBool('notification_marketing', _marketingEmails);

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Notification settings saved',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to save settings',
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 说明文本
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Manage your notification preferences. You can enable or disable different types of notifications.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 通知渠道设置
                _buildSectionTitle('Notification Channels'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.email),
                        title: const Text('Email Notifications'),
                        subtitle: const Text(
                            'Receive notifications via email'),
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active),
                        title: const Text('Push Notifications'),
                        subtitle: const Text(
                            'Receive push notifications on your device'),
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() {
                            _pushNotifications = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 通知类型设置
                _buildSectionTitle('Notification Types'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.folder),
                        title: const Text('Project Updates'),
                        subtitle: const Text(
                            'Deployment status, build results, and errors'),
                        value: _projectUpdates,
                        onChanged: (value) {
                          setState(() {
                            _projectUpdates = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.person_add),
                        title: const Text('Invite Notifications'),
                        subtitle: const Text(
                            'When someone accepts your invite'),
                        value: _inviteNotifications,
                        onChanged: (value) {
                          setState(() {
                            _inviteNotifications = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.campaign),
                        title: const Text('System Announcements'),
                        subtitle: const Text(
                            'Platform updates and important notices'),
                        value: _systemAnnouncements,
                        onChanged: (value) {
                          setState(() {
                            _systemAnnouncements = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.mail_outline),
                        title: const Text('Marketing Emails'),
                        subtitle: const Text(
                            'Product news, tips, and special offers'),
                        value: _marketingEmails,
                        onChanged: (value) {
                          setState(() {
                            _marketingEmails = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
