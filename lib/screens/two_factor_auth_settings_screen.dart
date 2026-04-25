import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:d1vai_app/widgets/adaptive_modal.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';

class TwoFactorAuthSettingsScreen extends StatefulWidget {
  const TwoFactorAuthSettingsScreen({super.key});

  @override
  State<TwoFactorAuthSettingsScreen> createState() =>
      _TwoFactorAuthSettingsScreenState();
}

class _TwoFactorAuthSettingsScreenState
    extends State<TwoFactorAuthSettingsScreen> {
  bool _isEnabled = false; // 2FA是否启用
  bool _isLoading = true;
  bool _isEnabling = false;
  String? _secret;
  List<String> _backupCodes = const <String>[];

  static const _prefsEnabledKey = 'two_factor_enabled';
  static const _prefsSecretKey = 'two_factor_secret';
  static const _prefsBackupCodesKey = 'two_factor_backup_codes';

  @override
  void initState() {
    super.initState();
    _loadTwoFactorStatus();
  }

  Future<void> _loadTwoFactorStatus() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsEnabledKey) ?? false;
      final secret = prefs.getString(_prefsSecretKey);
      final codes =
          prefs.getStringList(_prefsBackupCodesKey) ?? const <String>[];

      if (!mounted) return;

      setState(() {
        _isEnabled = enabled;
        _secret = secret;
        _backupCodes = codes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load 2FA status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enableTwoFactor() async {
    if (_isEnabling) return;

    setState(() {
      _isEnabling = true;
    });

    try {
      // 生成模拟的密钥和二维码
      final secret = _generateSecret();
      final qrCodeUrl = _generateQrCodeUrl(secret);
      final backupCodes = _generateBackupCodes();

      // 显示设置对话框
      if (!mounted) return;
      final ok = await _showSetupDialog(secret, qrCodeUrl, backupCodes);
      if (!mounted) return;
      if (ok != true) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsEnabledKey, true);
      await prefs.setString(_prefsSecretKey, secret);
      await prefs.setStringList(_prefsBackupCodesKey, backupCodes);

      if (!mounted) return;
      setState(() {
        _isEnabled = true;
        _secret = secret;
        _backupCodes = backupCodes;
      });
    } catch (e) {
      debugPrint('Failed to enable 2FA: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to enable 2FA: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnabling = false;
        });
      }
    }
  }

  Future<void> _disableTwoFactor() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Two-Factor Authentication'),
        content: const Text(
          'Are you sure you want to disable 2FA? Your account will be less secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsEnabledKey);
      await prefs.remove(_prefsSecretKey);
      await prefs.remove(_prefsBackupCodesKey);

      if (!mounted) return;

      setState(() {
        _isEnabled = false;
        _secret = null;
        _backupCodes = const <String>[];
      });

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Two-factor authentication has been disabled',
      );
    } catch (e) {
      debugPrint('Failed to disable 2FA: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to disable 2FA: $e',
        );
      }
    }
  }

  Future<bool?> _showSetupDialog(
    String secret,
    String qrCodeUrl,
    List<String> backupCodes,
  ) async {
    final codeController = TextEditingController();

    return showAdaptiveModal<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final qrSurface = Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
          theme.colorScheme.surfaceContainerLow,
        );
        final warningSurface = Color.alphaBlend(
          theme.colorScheme.tertiary.withValues(alpha: isDark ? 0.18 : 0.12),
          theme.colorScheme.surface,
        );

        return AdaptiveModalContainer(
          maxWidth: 620,
          mobileMaxHeightFactor: 0.98,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ListView(
              shrinkWrap: true,
              children: [
                AdaptiveModalHeader(
                  title: 'Set Up Two-Factor Authentication',
                  subtitle:
                      'Scan the QR code with your authenticator app or enter the secret key manually.',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: qrSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 模拟二维码（实际应用中会显示真实的二维码图片）
                      Container(
                        width: 200,
                        height: 200,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.qr_code,
                          size: 100,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scan this QR code with your authenticator app',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Secret Key:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          secret,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: secret));
                          if (context.mounted) {
                            SnackBarHelper.showSuccess(
                              context,
                              title: 'Copied',
                              message: 'Secret key copied to clipboard',
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Backup Codes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: warningSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(
                        alpha: isDark ? 0.55 : 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save these backup codes in a safe place. You can use them to access your account if you lose your authenticator device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: backupCodes
                            .map(
                              (code) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter verification code from your app:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    hintText: '123456',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            if (context.mounted) {
                              SnackBarHelper.showError(
                                context,
                                title: 'Error',
                                message:
                                    'Please enter a 6-digit verification code',
                              );
                            }
                            return;
                          }

                          Navigator.of(context, rootNavigator: true).pop(true);
                        },
                        child: const Text('Verify & Enable'),
                      ),
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

  String _generateSecret() {
    // 模拟生成TOTP密钥
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = chars.split('').toList()..shuffle();
    final secret = StringBuffer();
    for (int i = 0; i < 32; i++) {
      secret.write(random[i % random.length]);
    }
    return secret.toString();
  }

  String _generateQrCodeUrl(String secret) {
    // 模拟生成二维码URL
    final issuer = 'd1vai';
    final account = 'user@example.com';
    return 'otpauth://totp/$issuer:$account?secret=$secret&issuer=$issuer';
  }

  List<String> _generateBackupCodes() {
    // 生成10个备份码
    final codes = <String>[];
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < 10; i++) {
      final code = (random + i * 12345).toString();
      final formatted = '${code.substring(0, 4)}-${code.substring(4, 8)}';
      codes.add(formatted);
    }

    return codes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Authentication')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusCard(),
                if (_isEnabled) ...[
                  const SizedBox(height: 16),
                  _buildBackupCodesCard(),
                ],
                const SizedBox(height: 24),
                _buildInstructionsCard(),
                const SizedBox(height: 24),
                _buildActionButton(),
              ],
            ),
    );
  }

  Widget _buildBackupCodesCard() {
    final theme = Theme.of(context);
    final codes = _backupCodes;
    final secret = (_secret ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Backup codes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy all',
                  onPressed: codes.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: codes.join('\n')),
                          );
                          if (!mounted) return;
                          SnackBarHelper.showSuccess(
                            context,
                            title: 'Copied',
                            message: 'Backup codes copied',
                          );
                        },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Store these codes securely. Each code can be used once if you lose access to your authenticator.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (secret.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Secret: ${secret.substring(0, 6)}…${secret.substring(secret.length - 4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy secret',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: secret));
                        if (!mounted) return;
                        SnackBarHelper.showSuccess(
                          context,
                          title: 'Copied',
                          message: 'Secret key copied',
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (codes.isEmpty)
              Text(
                'No backup codes stored.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: codes
                    .take(10)
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _isEnabled ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isEnabled ? Icons.shield : Icons.shield_outlined,
              color: _isEnabled ? Colors.green.shade700 : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEnabled ? 'Two-Factor Enabled' : 'Two-Factor Disabled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isEnabled
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isEnabled
                        ? 'Your account is protected with 2FA'
                        : 'Add an extra layer of security to your account',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isEnabled
                          ? Colors.green.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isEnabled
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isEnabled ? 'Enabled' : 'Disabled',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How it works',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInstructionItem(
              '1',
              'Install an authenticator app',
              'Download Google Authenticator, Authy, or any TOTP-compatible app on your phone.',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              '2',
              'Scan the QR code',
              'Use your authenticator app to scan the QR code or enter the secret key manually.',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              '3',
              'Enter verification code',
              'Enter the 6-digit code from your authenticator app to verify the setup.',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              '4',
              'Save backup codes',
              'Save the backup codes in a safe place. You can use them to access your account if you lose your authenticator device.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    String number,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isEnabling
            ? null
            : _isEnabled
            ? _disableTwoFactor
            : _enableTwoFactor,
        icon: _isEnabling
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(_isEnabled ? Icons.shield : Icons.shield_outlined),
        label: Text(
          _isEnabling
              ? 'Setting up...'
              : _isEnabled
              ? 'Disable 2FA'
              : 'Enable 2FA',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEnabled ? Colors.red : Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
