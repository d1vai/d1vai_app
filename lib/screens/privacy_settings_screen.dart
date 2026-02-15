import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/snackbar_helper.dart';

class PrivacySettings {
  bool profileVisibility;
  bool showOnlineStatus;
  bool allowDataSharing;
  bool allowAnalytics;
  bool allowMarketingEmails;
  bool showActivityStatus;
  bool discoverableByEmail;
  bool allowThirdPartyIntegrations;

  PrivacySettings({
    required this.profileVisibility,
    required this.showOnlineStatus,
    required this.allowDataSharing,
    required this.allowAnalytics,
    required this.allowMarketingEmails,
    required this.showActivityStatus,
    required this.discoverableByEmail,
    required this.allowThirdPartyIntegrations,
  });

  factory PrivacySettings.defaultSettings() {
    return PrivacySettings(
      profileVisibility: true,
      showOnlineStatus: false,
      allowDataSharing: true,
      allowAnalytics: true,
      allowMarketingEmails: false,
      showActivityStatus: false,
      discoverableByEmail: true,
      allowThirdPartyIntegrations: true,
    );
  }

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      profileVisibility: json['profile_visibility'] as bool? ?? true,
      showOnlineStatus: json['show_online_status'] as bool? ?? false,
      allowDataSharing: json['allow_data_sharing'] as bool? ?? true,
      allowAnalytics: json['allow_analytics'] as bool? ?? true,
      allowMarketingEmails: json['allow_marketing_emails'] as bool? ?? false,
      showActivityStatus: json['show_activity_status'] as bool? ?? false,
      discoverableByEmail: json['discoverable_by_email'] as bool? ?? true,
      allowThirdPartyIntegrations:
          json['allow_third_party_integrations'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_visibility': profileVisibility,
      'show_online_status': showOnlineStatus,
      'allow_data_sharing': allowDataSharing,
      'allow_analytics': allowAnalytics,
      'allow_marketing_emails': allowMarketingEmails,
      'show_activity_status': showActivityStatus,
      'discoverable_by_email': discoverableByEmail,
      'allow_third_party_integrations': allowThirdPartyIntegrations,
    };
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  PrivacySettings _settings = PrivacySettings.defaultSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 在真实应用中，这里会从后端 API 加载设置
      // 现在使用本地存储作为演示
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _settings = PrivacySettings(
          profileVisibility:
              prefs.getBool('privacy_profile_visibility') ?? true,
          showOnlineStatus:
              prefs.getBool('privacy_show_online_status') ?? false,
          allowDataSharing: prefs.getBool('privacy_allow_data_sharing') ?? true,
          allowAnalytics: prefs.getBool('privacy_allow_analytics') ?? true,
          allowMarketingEmails:
              prefs.getBool('privacy_allow_marketing_emails') ?? false,
          showActivityStatus:
              prefs.getBool('privacy_show_activity_status') ?? false,
          discoverableByEmail:
              prefs.getBool('privacy_discoverable_by_email') ?? true,
          allowThirdPartyIntegrations:
              prefs.getBool('privacy_allow_third_party_integrations') ?? true,
        );
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
        message: 'Failed to load privacy settings',
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'privacy_profile_visibility',
        _settings.profileVisibility,
      );
      await prefs.setBool(
        'privacy_show_online_status',
        _settings.showOnlineStatus,
      );
      await prefs.setBool(
        'privacy_allow_data_sharing',
        _settings.allowDataSharing,
      );
      await prefs.setBool('privacy_allow_analytics', _settings.allowAnalytics);
      await prefs.setBool(
        'privacy_allow_marketing_emails',
        _settings.allowMarketingEmails,
      );
      await prefs.setBool(
        'privacy_show_activity_status',
        _settings.showActivityStatus,
      );
      await prefs.setBool(
        'privacy_discoverable_by_email',
        _settings.discoverableByEmail,
      );
      await prefs.setBool(
        'privacy_allow_third_party_integrations',
        _settings.allowThirdPartyIntegrations,
      );

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Privacy settings saved',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to save privacy settings',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildProfileVisibilitySection(),
                const SizedBox(height: 24),
                _buildDataSharingSection(),
                const SizedBox(height: 24),
                _buildActivitySection(),
                const SizedBox(height: 24),
                _buildThirdPartySection(),
                const SizedBox(height: 32),
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
                Icon(Icons.privacy_tip, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Your Privacy Matters',
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
              'Control how your data is used and who can see your information. '
              'You can update these settings at any time.',
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

  Widget _buildProfileVisibilitySection() {
    return _buildSection(
      'Profile Visibility',
      'Control who can see your profile information',
      [
        SwitchListTile(
          secondary: Icon(
            Icons.person,
            color: _settings.profileVisibility ? Colors.green : Colors.grey,
          ),
          title: const Text('Public Profile'),
          subtitle: const Text('Allow anyone to view your profile'),
          value: _settings.profileVisibility,
          onChanged: (value) {
            setState(() {
              _settings.profileVisibility = value;
            });
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: Icon(
            Icons.email,
            color: _settings.discoverableByEmail ? Colors.blue : Colors.grey,
          ),
          title: const Text('Discoverable by Email'),
          subtitle: const Text('Allow others to find you using your email'),
          value: _settings.discoverableByEmail,
          onChanged: (value) {
            setState(() {
              _settings.discoverableByEmail = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDataSharingSection() {
    return _buildSection('Data Sharing', 'Manage how your data is used', [
      SwitchListTile(
        secondary: Icon(
          Icons.analytics,
          color: _settings.allowAnalytics ? Colors.purple : Colors.grey,
        ),
        title: const Text('Allow Analytics'),
        subtitle: const Text('Help improve the app by sharing usage analytics'),
        value: _settings.allowAnalytics,
        onChanged: (value) {
          setState(() {
            _settings.allowAnalytics = value;
          });
        },
      ),
      const Divider(height: 1),
      SwitchListTile(
        secondary: Icon(
          Icons.share,
          color: _settings.allowDataSharing ? Colors.orange : Colors.grey,
        ),
        title: const Text('Allow Data Sharing'),
        subtitle: const Text('Share data to improve our services'),
        value: _settings.allowDataSharing,
        onChanged: (value) {
          setState(() {
            _settings.allowDataSharing = value;
          });
        },
      ),
      const Divider(height: 1),
      SwitchListTile(
        secondary: Icon(
          Icons.mark_email_unread,
          color: _settings.allowMarketingEmails ? Colors.red : Colors.grey,
        ),
        title: const Text('Marketing Emails'),
        subtitle: const Text('Receive emails about new features and offers'),
        value: _settings.allowMarketingEmails,
        onChanged: (value) {
          setState(() {
            _settings.allowMarketingEmails = value;
          });
        },
      ),
    ]);
  }

  Widget _buildActivitySection() {
    return _buildSection(
      'Activity Status',
      'Control your activity visibility',
      [
        SwitchListTile(
          secondary: Icon(
            Icons.circle,
            color: _settings.showOnlineStatus ? Colors.green : Colors.grey,
          ),
          title: const Text('Show Online Status'),
          subtitle: const Text('Let others see when you\'re active'),
          value: _settings.showOnlineStatus,
          onChanged: (value) {
            setState(() {
              _settings.showOnlineStatus = value;
            });
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: Icon(
            Icons.timeline,
            color: _settings.showActivityStatus ? Colors.blue : Colors.grey,
          ),
          title: const Text('Show Activity Status'),
          subtitle: const Text('Display your recent activity to others'),
          value: _settings.showActivityStatus,
          onChanged: (value) {
            setState(() {
              _settings.showActivityStatus = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildThirdPartySection() {
    return _buildSection(
      'Third-Party Integrations',
      'Manage connected applications',
      [
        SwitchListTile(
          secondary: Icon(
            Icons.extension,
            color: _settings.allowThirdPartyIntegrations
                ? Colors.indigo
                : Colors.grey,
          ),
          title: const Text('Allow Third-Party Apps'),
          subtitle: const Text('Enable integrations with third-party services'),
          value: _settings.allowThirdPartyIntegrations,
          onChanged: (value) {
            setState(() {
              _settings.allowThirdPartyIntegrations = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSection(String title, String subtitle, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
