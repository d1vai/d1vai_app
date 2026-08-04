import 'dart:async';
import 'package:flutter/material.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import '../services/d1vai_service.dart';

class ResetPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  final VoidCallback? onSuccess;

  const ResetPasswordDialog({super.key, this.initialEmail, this.onSuccess});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final D1vaiService _service = D1vaiService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _sending = false;
  bool _resetting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      _showError(
        context.tr('email_invalid', 'Please enter a valid email address'),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _service.postUserPasswordForgotSend(email);

      if (mounted) {
        _showSuccess(
          context.tr(
            'code_sent_success',
            'Verification code sent successfully',
          ),
        );
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isValidEmail(email)) {
      _showError(
        context.tr('email_invalid', 'Please enter a valid email address'),
      );
      return;
    }

    if (code.isEmpty || code.length < 4) {
      _showError(
        context.tr('verify_code_required', 'Please enter verification code'),
      );
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showError(
        context.tr(
          'password_length_error',
          'Password must be at least 6 characters',
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      _showError(
        context.tr('passwords_do_not_match', 'Passwords do not match'),
      );
      return;
    }

    setState(() {
      _resetting = true;
    });

    try {
      await _service.postUserPasswordReset(email, code, password);

      if (mounted) {
        _showSuccess(
          context.tr('password_reset_success', 'Password reset successfully'),
        );
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
          _resetting = false;
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
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.tr('reset_password', 'Reset Password')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email 输入框
            Text(
              context.tr('email', 'Email'),
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
            ),
            const SizedBox(height: 16),

            // 验证码输入框
            Text(
              context.tr('verify_code', 'Verification Code'),
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
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: _sending || _countdown > 0 ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      disabledForegroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.38),
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
                            _countdown > 0
                                ? '${_countdown}s'
                                : context.tr('send_code', 'Send Code'),
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 新密码输入框
            Text(
              context.tr('new_password', 'New Password'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: context.tr(
                  'enter_new_password',
                  'Enter new password',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 确认密码输入框
            Text(
              context.tr('confirm_password', 'Confirm Password'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: context.tr(
                  're_enter_new_password',
                  'Re-enter new password',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            loc?.translate('cancel') ?? 'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        ElevatedButton(
          onPressed: _resetting ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            disabledForegroundColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _resetting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(context.tr('reset_password', 'Reset Password')),
        ),
      ],
    );
  }
}
