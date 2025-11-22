import 'package:flutter/material.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

enum SecurityEventType {
  passwordChange('Password Changed', Icons.lock, Colors.orange),
  emailChange('Email Changed', Icons.email, Colors.blue),
  twoFactorEnabled('2FA Enabled', Icons.shield, Colors.green),
  twoFactorDisabled('2FA Disabled', Icons.shield_outlined, Colors.red),
  apiKeyCreated('API Key Created', Icons.vpn_key, Colors.purple),
  apiKeyDeleted('API Key Deleted', Icons.vpn_key, Colors.red),
  walletConnected('Wallet Connected', Icons.wallet, Colors.green),
  walletDisconnected('Wallet Disconnected', Icons.wallet, Colors.grey),
  loginFromNewDevice('New Device Login', Icons.devices, Colors.blue),
  profileUpdated('Profile Updated', Icons.person, Colors.deepPurple),
  githubConnected('GitHub Connected', Icons.code, Colors.black),
  githubDisconnected('GitHub Disconnected', Icons.code, Colors.grey),
  settingsChanged('Settings Changed', Icons.settings, Colors.blueGrey);

  const SecurityEventType(this.displayName, this.icon, this.color);
  final String displayName;
  final IconData icon;
  final Color color;
}

class SecurityActivity {
  final String id;
  final SecurityEventType eventType;
  final String description;
  final DateTime timestamp;
  final String? details;
  final String? ipAddress;

  SecurityActivity({
    required this.id,
    required this.eventType,
    required this.description,
    required this.timestamp,
    this.details,
    this.ipAddress,
  });

  factory SecurityActivity.fromJson(Map<String, dynamic> json) {
    final eventTypeString = json['event_type'] as String;
    final eventType = SecurityEventType.values.firstWhere(
      (e) => e.name == eventTypeString,
      orElse: () => SecurityEventType.settingsChanged,
    );

    return SecurityActivity(
      id: json['id'] as String,
      eventType: eventType,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as String?,
      ipAddress: json['ip_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType.name,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
      'ip_address': ipAddress,
    };
  }
}

class SecurityActivityScreen extends StatefulWidget {
  const SecurityActivityScreen({super.key});

  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  List<SecurityActivity> _activities = [];
  bool _isLoading = true;
  SecurityEventType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadSecurityActivity();
  }

  Future<void> _loadSecurityActivity() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final data = await _d1vaiService.getSecurityActivity();
      if (mounted) {
        setState(() {
          _activities = data.map((json) => SecurityActivity.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load security activity: $e');
      if (mounted) {
        // 如果 API 不存在，使用模拟数据
        if (e.toString().contains('404') || e.toString().contains('Not Found')) {
          _loadMockSecurityActivity();
        } else {
          setState(() {
            _isLoading = false;
          });
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to load security activity: $e',
          );
        }
      }
    }
  }

  void _loadMockSecurityActivity() {
    final now = DateTime.now();
    setState(() {
      _activities = [
        SecurityActivity(
          id: '1',
          eventType: SecurityEventType.loginFromNewDevice,
          description: 'Login from new device',
          timestamp: now.subtract(const Duration(hours: 2)),
          details: 'Chrome on iPhone',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '2',
          eventType: SecurityEventType.profileUpdated,
          description: 'Profile information updated',
          timestamp: now.subtract(const Duration(hours: 5)),
          details: 'Updated company name',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '3',
          eventType: SecurityEventType.twoFactorEnabled,
          description: 'Two-factor authentication enabled',
          timestamp: now.subtract(const Duration(days: 1)),
          details: 'Authenticator app',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '4',
          eventType: SecurityEventType.apiKeyCreated,
          description: 'New API key created',
          timestamp: now.subtract(const Duration(days: 2)),
          details: 'Production Key',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '5',
          eventType: SecurityEventType.walletConnected,
          description: 'Solana wallet connected',
          timestamp: now.subtract(const Duration(days: 3)),
          details: 'A1B2C3...X9Y8Z7',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '6',
          eventType: SecurityEventType.githubConnected,
          description: 'GitHub account connected',
          timestamp: now.subtract(const Duration(days: 5)),
          details: 'Personal access token',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '7',
          eventType: SecurityEventType.emailChange,
          description: 'Email address changed',
          timestamp: now.subtract(const Duration(days: 7)),
          details: 'From old@example.com to new@example.com',
          ipAddress: '192.168.1.100',
        ),
        SecurityActivity(
          id: '8',
          eventType: SecurityEventType.passwordChange,
          description: 'Password changed',
          timestamp: now.subtract(const Duration(days: 10)),
          ipAddress: '192.168.1.100',
        ),
      ];
      _isLoading = false;
    });
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
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }

  List<SecurityActivity> get _filteredActivities {
    if (_filterType == null) {
      return _activities;
    }
    return _activities.where((a) => a.eventType == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSecurityActivity,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? _buildEmptyState()
              : _buildActivityList(),
      floatingActionButton: _activities.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showFilterDialog(),
              child: const Icon(Icons.filter_list),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No security activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your security events will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = _filteredActivities[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activity.eventType.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    activity.eventType.icon,
                    color: activity.eventType.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (activity.details != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.details!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
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
                            _formatDateTime(activity.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (activity.ipAddress != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.language,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.ipAddress!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    SecurityEventType? selectedFilter = _filterType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Events'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<SecurityEventType?>(
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<SecurityEventType?>(
                    value: null,
                    child: Text('All Events'),
                  ),
                  ...SecurityEventType.values.map((type) => DropdownMenuItem<SecurityEventType?>(
                    value: type,
                    child: Text(type.displayName),
                  )),
                ],
                onChanged: (value) {
                  selectedFilter = value;
                },
              ),
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
              Navigator.of(context).pop();
              setState(() {
                _filterType = selectedFilter;
              });
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
