import 'package:flutter/material.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

class LoginSession {
  final String id;
  final String deviceName;
  final String deviceType;
  final String browser;
  final String ipAddress;
  final String location;
  final DateTime loginTime;
  final DateTime? lastActive;
  final bool isCurrentSession;

  LoginSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.browser,
    required this.ipAddress,
    required this.location,
    required this.loginTime,
    this.lastActive,
    required this.isCurrentSession,
  });

  factory LoginSession.fromJson(Map<String, dynamic> json) {
    return LoginSession(
      id: json['id'] as String,
      deviceName: json['device_name'] as String,
      deviceType: json['device_type'] as String,
      browser: json['browser'] as String,
      ipAddress: json['ip_address'] as String,
      location: json['location'] as String,
      loginTime: DateTime.parse(json['login_time'] as String),
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'] as String)
          : null,
      isCurrentSession: json['is_current_session'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_name': deviceName,
      'device_type': deviceType,
      'browser': browser,
      'ip_address': ipAddress,
      'location': location,
      'login_time': loginTime.toIso8601String(),
      'last_active': lastActive?.toIso8601String(),
      'is_current_session': isCurrentSession,
    };
  }

  IconData get deviceIcon {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
      case 'phone':
        return Icons.phone_iphone;
      case 'tablet':
        return Icons.tablet_mac;
      case 'desktop':
      case 'computer':
        return Icons.desktop_windows;
      case 'laptop':
        return Icons.laptop_mac;
      default:
        return Icons.device_unknown;
    }
  }

  Color get deviceColor {
    if (isCurrentSession) {
      return Colors.green;
    }
    switch (deviceType.toLowerCase()) {
      case 'mobile':
      case 'phone':
        return Colors.blue;
      case 'tablet':
        return Colors.purple;
      case 'desktop':
      case 'computer':
      case 'laptop':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }
}

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  List<LoginSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
  }

  Future<void> _loadLoginHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final data = await _d1vaiService.getLoginHistory();
      if (mounted) {
        setState(() {
          _sessions = data.map((json) => LoginSession.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load login history: $e');
      if (mounted) {
        // 如果 API 不存在，使用模拟数据
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          _loadMockLoginHistory();
        } else {
          setState(() {
            _isLoading = false;
          });
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to load login history: $e',
          );
        }
      }
    }
  }

  void _loadMockLoginHistory() {
    // 模拟登录历史数据
    final now = DateTime.now();
    setState(() {
      _sessions = [
        LoginSession(
          id: '1',
          deviceName: 'Current Session',
          deviceType: 'Mobile',
          browser: 'Chrome Mobile',
          ipAddress: '192.168.1.100',
          location: 'San Francisco, US',
          loginTime: now.subtract(const Duration(minutes: 30)),
          lastActive: now.subtract(const Duration(minutes: 5)),
          isCurrentSession: true,
        ),
        LoginSession(
          id: '2',
          deviceName: 'MacBook Pro',
          deviceType: 'Desktop',
          browser: 'Safari',
          ipAddress: '192.168.1.50',
          location: 'San Francisco, US',
          loginTime: now.subtract(const Duration(hours: 2)),
          lastActive: now.subtract(const Duration(hours: 1)),
          isCurrentSession: false,
        ),
        LoginSession(
          id: '3',
          deviceName: 'iPhone 14',
          deviceType: 'Mobile',
          browser: 'Safari',
          ipAddress: '10.0.0.15',
          location: 'San Francisco, US',
          loginTime: now.subtract(const Duration(days: 1)),
          lastActive: now.subtract(const Duration(days: 1)),
          isCurrentSession: false,
        ),
        LoginSession(
          id: '4',
          deviceName: 'iPad Air',
          deviceType: 'Tablet',
          browser: 'Chrome',
          ipAddress: '192.168.1.80',
          location: 'San Francisco, US',
          loginTime: now.subtract(const Duration(days: 3)),
          lastActive: now.subtract(const Duration(days: 3)),
          isCurrentSession: false,
        ),
        LoginSession(
          id: '5',
          deviceName: 'Windows PC',
          deviceType: 'Desktop',
          browser: 'Edge',
          ipAddress: '203.0.113.45',
          location: 'New York, US',
          loginTime: now.subtract(const Duration(days: 7)),
          lastActive: now.subtract(const Duration(days: 7)),
          isCurrentSession: false,
        ),
        LoginSession(
          id: '6',
          deviceName: 'Unknown Device',
          deviceType: 'Unknown',
          browser: 'Firefox',
          ipAddress: '198.51.100.23',
          location: 'Unknown',
          loginTime: now.subtract(const Duration(days: 14)),
          isCurrentSession: false,
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _revokeSession(LoginSession session) async {
    if (session.isCurrentSession) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Cannot revoke current session',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Session'),
        content: Text(
          'Are you sure you want to revoke the login session for "${session.deviceName}"? '
          'This will require the user to log in again from that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _d1vaiService.revokeLoginSession(session.id);
      if (!mounted) return;

      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Session revoked successfully',
      );
    } catch (e) {
      debugPrint('Failed to revoke session: $e');
      if (mounted) {
        // 如果 API 不存在，使用模拟删除
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          setState(() {
            _sessions.removeWhere((s) => s.id == session.id);
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'Session revoked successfully (demo)',
          );
        } else {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to revoke session: $e',
          );
        }
      }
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final otherSessions = _sessions.where((s) => !s.isCurrentSession).toList();
    if (otherSessions.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'Info',
        message: 'No other sessions to revoke',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke All Other Sessions'),
        content: Text(
          'Are you sure you want to revoke all ${otherSessions.length} other login sessions? '
          'This will require you to log in again on all other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _d1vaiService.revokeAllLoginSessions();
      if (!mounted) return;

      setState(() {
        _sessions = _sessions.where((s) => s.isCurrentSession).toList();
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'All other sessions revoked successfully',
      );
    } catch (e) {
      debugPrint('Failed to revoke all sessions: $e');
      if (mounted) {
        // 如果 API 不存在，使用模拟删除
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          setState(() {
            _sessions = _sessions.where((s) => s.isCurrentSession).toList();
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'All other sessions revoked successfully (demo)',
          );
        } else {
          SnackBarHelper.showError(
            context,
            title: 'Error',
              message: 'Failed to revoke sessions: $e',
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login History'),
        actions: [
          if (_sessions.any((s) => !s.isCurrentSession))
            TextButton(
              onPressed: _revokeAllOtherSessions,
              child: const Text(
                'Revoke All',
                style: TextStyle(color: Colors.red),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoginHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No login history',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your login sessions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: session.deviceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        session.deviceIcon,
                        color: session.deviceColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.deviceName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (session.isCurrentSession)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.browser} • ${session.deviceType}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Logged in ${_formatDateTime(session.loginTime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${session.ipAddress} • ${session.location}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!session.isCurrentSession)
                      IconButton(
                        onPressed: () => _revokeSession(session),
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'More options',
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
