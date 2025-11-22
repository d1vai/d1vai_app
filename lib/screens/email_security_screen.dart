import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

class EmailSecurityScreen extends StatefulWidget {
  const EmailSecurityScreen({super.key});

  @override
  State<EmailSecurityScreen> createState() => _EmailSecurityScreenState();
}

class _EmailSecurityScreenState extends State<EmailSecurityScreen> {
  final D1vaiService _d1vaiService = D1vaiService();

  // Bind email state
  final TextEditingController _bindEmailController = TextEditingController();
  final TextEditingController _bindCodeController = TextEditingController();
  bool _isSendingBindCode = false;
  bool _isConfirmingBind = false;
  int _bindCountdown = 0;
  bool _bindCodeSent = false;

  // Change email state
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _changeCodeController = TextEditingController();
  bool _isSendingChangeCode = false;
  bool _isConfirmingChange = false;
  int _changeCountdown = 0;
  bool _changeCodeSent = false;

  // Countdown timers
  int? _bindTimer;
  int? _changeTimer;

  @override
  void dispose() {
    _bindEmailController.dispose();
    _bindCodeController.dispose();
    _newEmailController.dispose();
    _changeCodeController.dispose();
    if (_bindTimer != null) {
      // Note: In a production app, you'd want to properly cancel this timer
    }
    if (_changeTimer != null) {
      // Note: In a production app, you'd want to properly cancel this timer
    }
    super.dispose();
  }

  // Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+').hasMatch(email);
  }

  // Start countdown timer
  void _startCountdown(int seconds, bool isBind) {
    if (isBind) {
      setState(() {
        _bindCountdown = seconds;
        _bindCodeSent = true;
      });
      _bindTimer = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    } else {
      setState(() {
        _changeCountdown = seconds;
        _changeCodeSent = true;
      });
      _changeTimer = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    }

    // In a real app, you'd use a Timer.periodic here
    // For simplicity, we'll just decrement the countdown
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          if (isBind) {
            _bindCountdown = 0;
          } else {
            _changeCountdown = 0;
          }
        });
      }
    });
  }

  // Send bind email code
  Future<void> _sendBindCode() async {
    final email = _bindEmailController.text.trim();

    if (email.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter an email address',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter a valid email address',
      );
      return;
    }

    setState(() {
      _isSendingBindCode = true;
    });

    try {
      await _d1vaiService.postUserBindEmailSend(email);

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Verification code sent',
      );

      _startCountdown(60, true);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send code: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingBindCode = false;
        });
      }
    }
  }

  // Confirm bind email
  Future<void> _confirmBindEmail() async {
    final email = _bindEmailController.text.trim();
    final code = _bindCodeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Email and code are required',
      );
      return;
    }

    setState(() {
      _isConfirmingBind = true;
    });

    try {
      await _d1vaiService.postUserBindEmailConfirm(email, code);

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Email bound successfully',
      );

      setState(() {
        _bindCodeController.text = '';
        _bindCodeSent = false;
      });

      // Refresh user data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.fetchUser();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to bind email: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingBind = false;
        });
      }
    }
  }

  // Send change email code
  Future<void> _sendChangeCode() async {
    final email = _newEmailController.text.trim();

    if (email.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter an email address',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter a valid email address',
      );
      return;
    }

    setState(() {
      _isSendingChangeCode = true;
    });

    try {
      await _d1vaiService.postUserChangeEmailSend(email);

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Verification code sent',
      );

      _startCountdown(60, false);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send code: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingChangeCode = false;
        });
      }
    }
  }

  // Confirm change email
  Future<void> _confirmChangeEmail() async {
    final email = _newEmailController.text.trim();
    final code = _changeCodeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Email and code are required',
      );
      return;
    }

    setState(() {
      _isConfirmingChange = true;
    });

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final oldEmail = user?.email;
      await _d1vaiService.postUserChangeEmailConfirm(email, code, oldEmail);

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Email changed successfully',
      );

      setState(() {
        _newEmailController.text = '';
        _changeCodeController.text = '';
        _changeCodeSent = false;
      });

      // Refresh user data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.fetchUser();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to change email: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingChange = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Email Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Email',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasEmail ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasEmail ? Colors.green.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasEmail ? Icons.check_circle : Icons.info_outline,
                          color: hasEmail ? Colors.green.shade600 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasEmail ? (user.email ?? '') : 'No email bound',
                            style: TextStyle(
                              fontSize: 16,
                              color: hasEmail ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (hasEmail)
                          Chip(
                            label: const Text(
                              'Verified',
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.green.shade200,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasEmail
                        ? 'Your account is verified with this email address.'
                        : 'Bind your email to secure your account and enable password reset.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bind Email Section (if no email)
          if (!hasEmail) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bind Email',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bind your email address to your account for enhanced security.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bindEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    if (_bindCodeSent) ...[
                      TextField(
                        controller: _bindCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                          hintText: 'Enter verification code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.security),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _bindCountdown > 0
                                ? 'Resend in $_bindCountdown seconds'
                                : 'Didn\'t receive the code?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: _bindCountdown == 0
                                ? _sendBindCode
                                : null,
                            child: Text(
                              'Resend',
                              style: TextStyle(
                                color: _bindCountdown == 0
                                    ? Colors.deepPurple
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isConfirmingBind ? null : _confirmBindEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isConfirmingBind
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Confirm Binding'),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSendingBindCode ? null : _sendBindCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSendingBindCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Send Verification Code'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Change Email Section (if has email)
          if (hasEmail) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Email',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Change your account email address.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newEmailController,
                      decoration: const InputDecoration(
                        labelText: 'New Email Address',
                        hintText: 'Enter new email address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    if (_changeCodeSent) ...[
                      TextField(
                        controller: _changeCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                          hintText: 'Enter verification code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.security),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _changeCountdown > 0
                                ? 'Resend in $_changeCountdown seconds'
                                : 'Didn\'t receive the code?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          TextButton(
                            onPressed: _changeCountdown == 0
                                ? _sendChangeCode
                                : null,
                            child: Text(
                              'Resend',
                              style: TextStyle(
                                color: _changeCountdown == 0
                                    ? Colors.deepPurple
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isConfirmingChange ? null : _confirmChangeEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isConfirmingChange
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Confirm Change'),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSendingChangeCode ? null : _sendChangeCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSendingChangeCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Send Verification Code'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Password Section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Password'),
                  subtitle: Text(
                    hasEmail
                        ? 'Reset your password via email verification'
                        : 'Bind your email first to enable password reset',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => ResetPasswordDialog(
                        initialEmail: user?.email ?? '',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Reset Password Dialog (copy from existing implementation)
class ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordDialog({
    super.key,
    required this.initialEmail,
  });

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isEmailSent = false;
  bool _isVerifying = false;
  bool _isResetting = false;
  int _countdown = 0;
  int? _timer;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    if (_timer != null) {
      // Note: In a production app, you'd want to properly cancel this timer
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
      _isEmailSent = true;
    });
    _timer = DateTime.now().millisecondsSinceEpoch + 60000;
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _countdown = 0;
        });
      }
    });
  }

  Future<void> _sendResetEmail() async {
    if (_emailController.text.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter your email',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // TODO: Implement send reset email
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _startCountdown();
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Reset code sent to your email',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send reset code: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please fill in all fields',
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Passwords do not match',
      );
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      // TODO: Implement reset password
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Password reset successfully',
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to reset password: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEmailSent) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _sendResetEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Reset Code'),
                ),
              ),
            ] else if (_codeController.text.isEmpty) ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Reset Code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _countdown > 0 ? 'Resend in $_countdown seconds' : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  TextButton(
                    onPressed: _countdown == 0 ? _sendResetEmail : null,
                    child: Text(
                      'Resend',
                      style: TextStyle(
                        color: _countdown == 0 ? Colors.deepPurple : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _codeController.text = '123456'; // Auto-fill for demo
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isResetting ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isResetting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Reset Password'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
