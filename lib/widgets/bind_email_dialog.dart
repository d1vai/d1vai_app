import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/d1vai_service.dart';
import '../providers/auth_provider.dart';

enum EmailDialogMode { bind, change }

class BindEmailDialog extends StatefulWidget {
  final String? initialEmail;
  final EmailDialogMode mode;
  final VoidCallback? onSuccess;

  const BindEmailDialog({
    super.key,
    this.initialEmail,
    this.mode = EmailDialogMode.bind,
    this.onSuccess,
  });

  @override
  State<BindEmailDialog> createState() => _BindEmailDialogState();
}

class _BindEmailDialogState extends State<BindEmailDialog> {
  final D1vaiService _service = D1vaiService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sending = false;
  bool _confirming = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'.+@.+\..+').hasMatch(email);
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      if (widget.mode == EmailDialogMode.change) {
        await _service.postUserChangeEmailSend(email);
      } else {
        await _service.postUserBindEmailSend(email);
      }

      if (mounted) {
        _showSuccess('Verification code sent');
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email');
      return;
    }

    if (code.isEmpty || code.length < 4) {
      _showError('Please enter the verification code');
      return;
    }

    setState(() {
      _confirming = true;
    });

    try {
      if (widget.mode == EmailDialogMode.change) {
        await _service.postUserChangeEmailConfirm(email, code);
        if (mounted) {
          _showSuccess('Email changed successfully');
        }
      } else {
        await _service.postUserBindEmailConfirm(email, code);
        if (mounted) {
          _showSuccess('Email bound successfully');
        }
      }

      // 刷新用户资料
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.fetchUser();

        if (!mounted) return;

        Navigator.of(context).pop();
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.mode == EmailDialogMode.change ? 'Change Email' : 'Bind Email',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email 输入框
            Text(
              'Email',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'm@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!_isValidEmail(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 验证码输入框
            Text(
              'Verification Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '6-digit code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the code';
                      }
                      if (value.length < 4) {
                        return 'Code must be at least 4 digits';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: _sending || _countdown > 0 ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _countdown > 0 ? '${_countdown}s' : 'Send Code',
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        ElevatedButton(
          onPressed: _confirming ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _confirming
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
