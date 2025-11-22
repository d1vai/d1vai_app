import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/snackbar_helper.dart';

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

      // 尝试从API获取2FA状态
      // 在实际实现中，这里会调用后端API
      // 由于API可能不存在，我们使用模拟数据

      // 模拟API延迟
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
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
      // 模拟生成2FA密钥和二维码
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      // 生成模拟的密钥和二维码
      final secret = _generateSecret();
      final qrCodeUrl = _generateQrCodeUrl(secret);
      final backupCodes = _generateBackupCodes();

      // 显示设置对话框
      if (!mounted) return;
      await _showSetupDialog(secret, qrCodeUrl, backupCodes);

      // 在真实应用中，这里会确认用户已正确设置2FA
      // 然后调用API启用2FA

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
      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
        _isEnabled = false;
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

  Future<void> _showSetupDialog(
    String secret,
    String qrCodeUrl,
    List<String> backupCodes,
  ) async {
    final codeController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set Up Two-Factor Authentication'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Scan the QR code with your authenticator app or enter the secret key manually.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // 模拟二维码（实际应用中会显示真实的二维码图片）
                    Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.qr_code,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan this QR code with your authenticator app',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  color: Colors.grey.shade100,
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save these backup codes in a safe place. You can use them to access your account if you lose your authenticator device.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) {
                if (context.mounted) {
                  SnackBarHelper.showError(
                    context,
                    title: 'Error',
                    message: 'Please enter a 6-digit verification code',
                  );
                }
                return;
              }

              // 模拟验证代码
              await Future.delayed(const Duration(milliseconds: 500));

              if (!context.mounted) return;

              Navigator.of(context, rootNavigator: true).pop();

              if (!mounted) return;

              // 启用2FA
              setState(() {
                _isEnabled = true;
              });

              if (!mounted) return;

              SnackBarHelper.showSuccess(
                context,
                title: 'Success',
                message: 'Two-factor authentication has been enabled',
              );
            },
            child: const Text('Verify & Enable'),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusCard(),
                const SizedBox(height: 24),
                _buildInstructionsCard(),
                const SizedBox(height: 24),
                _buildActionButton(),
              ],
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
                color: _isEnabled ? Colors.green.shade600 : Colors.grey.shade400,
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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

  Widget _buildInstructionItem(String number, String title, String description) {
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
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
        onPressed: _isEnabling ? null : _isEnabled ? _disableTwoFactor : _enableTwoFactor,
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
        label: Text(_isEnabling ? 'Setting up...' : _isEnabled ? 'Disable 2FA' : 'Enable 2FA'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEnabled ? Colors.red : Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
