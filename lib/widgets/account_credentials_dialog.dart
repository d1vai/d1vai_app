import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/d1vai_service.dart';
import 'adaptive_modal.dart';
import 'snackbar_helper.dart';

enum AccountCredentialAction { bindEmail, resetPassword }

Future<void> showAccountCredentialDialog(
  BuildContext context, {
  required AccountCredentialAction action,
}) {
  return showAdaptiveModal<void>(
    context: context,
    builder: (_) => _AccountCredentialDialog(action: action),
  );
}

class _AccountCredentialDialog extends StatefulWidget {
  final AccountCredentialAction action;

  const _AccountCredentialDialog({required this.action});

  @override
  State<_AccountCredentialDialog> createState() =>
      _AccountCredentialDialogState();
}

class _AccountCredentialDialogState extends State<_AccountCredentialDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _service = D1vaiService();
  bool _submitting = false;
  bool _codeSent = false;

  bool get _isBindEmail => widget.action == AccountCredentialAction.bindEmail;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t('email_invalid', 'Please enter a valid email address'),
      );
      return;
    }
    if (!_codeSent) {
      setState(() => _submitting = true);
      try {
        if (_isBindEmail) {
          await _service.postUserBindEmailSend(email);
        } else {
          await _service.postUserPasswordForgotSend(email);
        }
        if (!mounted) return;
        setState(() => _codeSent = true);
      } catch (error) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          title: _t('error', 'Error'),
          message: error.toString(),
        );
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    if (_code.text.trim().length != 6) {
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t(
          'verify_code_complete',
          'Please enter a 6-digit verification code',
        ),
      );
      return;
    }
    if (!_isBindEmail &&
        (_password.text.length < 8 ||
            _password.text != _confirmPassword.text)) {
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: _t(
          'passwords_do_not_match',
          'Passwords must match and contain at least 8 characters',
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_isBindEmail) {
        await _service.postUserBindEmailConfirm(email, _code.text.trim());
        if (mounted) await context.read<AuthProvider>().refreshUser();
      } else {
        await _service.postUserPasswordReset(
          email,
          _code.text.trim(),
          _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: _isBindEmail
            ? _t('email_bound_success', 'Email bound successfully')
            : _t('password_reset_success', 'Password reset successfully'),
      );
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isBindEmail
        ? _t('bind_email', 'Bind Email')
        : _t('reset_password', 'Reset Password');
    return AdaptiveModalContainer(
      maxWidth: 520,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveModalHeader(
              title: title,
              onClose: () => Navigator.of(context).pop(),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              enabled: !_codeSent,
              decoration: InputDecoration(labelText: _t('email', 'Email')),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: _t('verify_code', 'Verification code'),
                ),
              ),
              if (!_isBindEmail) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _t('new_password', 'New password'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _t('confirm_password', 'Confirm password'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _codeSent
                            ? _t('confirm', 'Confirm')
                            : _t('send_code', 'Send code'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
