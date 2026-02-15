import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/widgets/otp_input_field.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';
import 'package:d1vai_app/widgets/auth/login_legal_links.dart';
import 'package:d1vai_app/widgets/auth/session_expired_banner.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';

/// 登录模式枚举
enum LoginMode {
  code('code'),
  password('password');

  const LoginMode(this.value);
  final String value;

  String getLabel(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) {
      // 使用英文作为默认回退，确保多语言一致性
      return switch (this) {
        code => 'Login with Code',
        password => 'Login with Password',
      };
    }
    return switch (this) {
      code => loc.translate('login_with_code'),
      password => loc.translate('login_with_password'),
    };
  }

  static LoginMode fromString(String code) {
    return LoginMode.values.firstWhere(
      (mode) => mode.value == code,
      orElse: () => LoginMode.code,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool sessionExpired;

  const LoginScreen({super.key, this.sessionExpired = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 登录模式
  LoginMode _loginMode = LoginMode.code;

  // 登录相关状态
  bool _isLoading = false;
  bool _isSendingCode = false;

  // 验证码发送状态
  bool _isCodeSent = false;

  // 倒计时相关
  Timer? _countdownTimer;
  int _countdownSeconds = 60;
  String _countdownText = '';

  // OTP 码
  String _otpCode = '';

  bool _showSessionExpiredBanner = false;

  @override
  void initState() {
    super.initState();
    _countdownText = '';
    _showSessionExpiredBanner = widget.sessionExpired;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    // 安全地取消计时器
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  /// 启动倒计时定时器
  void _startCountdownTimer() {
    // 取消之前的计时器
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 检查组件是否已卸载
      if (!mounted) {
        timer.cancel();
        _countdownTimer = null;
        return;
      }

      if (_countdownSeconds == 0) {
        timer.cancel();
        _countdownTimer = null;
        setState(() {
          _countdownText = '';
        });
      } else {
        final loc = AppLocalizations.of(context);
        final suffix = loc?.translate('resend_after') ?? '秒后重发';
        setState(() {
          _countdownSeconds--;
          _countdownText = '$_countdownSeconds$suffix';
        });
      }
    });
  }

  /// 重置倒计时
  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 60;
    final loc = AppLocalizations.of(context);
    final suffix = loc?.translate('resend_after') ?? '秒后重发';
    setState(() {
      _countdownText = '60$suffix';
    });
    _startCountdownTimer();
  }

  /// 处理模式切换
  void _onModeChanged(LoginMode mode) {
    setState(() {
      _loginMode = mode;
      _otpCode = '';
      _isCodeSent = false;
      _countdownSeconds = 60;
      _countdownText = '';
      _countdownTimer?.cancel();
    });
  }

  /// 处理 OTP 完成输入
  void _onOtpCompleted(String code) {
    _otpCode = code;
    if (_emailController.text.isNotEmpty) {
      _loginWithCode();
    }
  }

  /// 处理 OTP 输入改变
  void _onOtpChanged(String code) {
    _otpCode = code;
  }

  /// 显示错误消息
  void _showError(String message) {
    debugPrint(message);
    final loc = AppLocalizations.of(context);
    final title = loc?.translate('login_failed') ?? '登录失败';
    if (mounted) {
      SnackBarHelper.showError(context, title: title, message: message);
    }
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    final loc = AppLocalizations.of(context);
    final title = loc?.translate('success') ?? '成功';
    if (mounted) {
      SnackBarHelper.showSuccess(context, title: title, message: message);
    }
  }

  /// 验证码登录
  Future<void> _loginWithCode() async {
    final loc = AppLocalizations.of(context);
    if (_emailController.text.isEmpty) {
      _showError(loc?.translate('email_required') ?? '请输入邮箱地址');
      return;
    }
    if (_otpCode.length != 6) {
      _showError(loc?.translate('verify_code_complete') ?? '请输入完整的验证码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).verifyCodeAndLogin(_emailController.text.trim(), _otpCode);
      _showSuccess(loc?.translate('login_success') ?? '登录成功');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 密码登录
  Future<void> _loginWithPassword() async {
    final loc = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(_emailController.text.trim(), _passwordController.text);
      _showSuccess(loc?.translate('login_success') ?? '登录成功');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    final loc = AppLocalizations.of(context);
    if (_emailController.text.isEmpty) {
      _showError(loc?.translate('email_required') ?? '请输入邮箱地址');
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).sendVerifyCode(_emailController.text.trim());

      // 标记验证码已发送，显示输入框
      setState(() {
        _isCodeSent = true;
      });

      _resetCountdown();
      _showSuccess(loc?.translate('code_sent_success') ?? '验证码已发送，请查收邮件');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                if (_showSessionExpiredBanner) ...[
                  SessionExpiredBanner(
                    title:
                        loc?.translate('session_expired_title') ??
                        'Session expired',
                    message:
                        loc?.translate('session_expired_message') ??
                        'Your login has expired. Please log in again.',
                    onClose: () {
                      if (!mounted) return;
                      setState(() => _showSessionExpiredBanner = false);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Logo
                const Text(
                  'd1vai',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // 模式切换标签
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: LoginMode.values.map((mode) {
                      final isSelected = mode == _loginMode;
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _onModeChanged(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cs.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                              child: Text(
                                mode.getLabel(context),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // 邮箱输入
                if (!_isCodeSent)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: loc?.translate('email_address') ?? '邮箱地址',
                      hintText: loc?.translate('enter_email') ?? '请输入您的邮箱',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.translate('email_required') ?? '请输入邮箱地址';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return loc?.translate('email_invalid') ?? '请输入有效的邮箱地址';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 24),

                // 根据模式显示不同内容
                if (_loginMode == LoginMode.password) ...[
                  // 密码登录
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: loc?.translate('password') ?? '密码',
                      hintText: loc?.translate('enter_password') ?? '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.translate('password_required') ?? '请输入密码';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  // 验证码登录
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isCodeSent) ...[
                        // 发送验证码按钮 - 始终显示在顶部
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed:
                                      _isSendingCode ||
                                          (_countdownSeconds < 60 &&
                                              _isCodeSent)
                                      ? null
                                      : _sendCode,
                                  icon: _isSendingCode
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.deepPurple,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_outlined,
                                          size: 18,
                                          color: Colors.deepPurple,
                                        ),
                                  label: Text(
                                    _isSendingCode
                                        ? loc?.translate('sending') ?? '发送中...'
                                        : (_countdownSeconds < 60 && _isCodeSent
                                              ? _countdownText
                                              : (_isCodeSent
                                                    ? loc?.translate(
                                                            'resend_code',
                                                          ) ??
                                                          '重新发送验证码'
                                                    : loc?.translate(
                                                            'send_code',
                                                          ) ??
                                                          '发送验证码')),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // 验证码输入框 - 只有发送后才显示
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${loc?.translate('code_sent_to') ?? '验证码已发送至'} ${_emailController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            OptimizedOtpInput(
                              count: 6,
                              onCompleted: _onOtpCompleted,
                              onChanged: _onOtpChanged,
                              autoSubmit: true,
                            ),
                            const SizedBox(height: 32),

                            // 验证按钮
                            ElevatedButton(
                              onPressed: _isLoading ? null : _loginWithCode,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      loc?.translate('verify_and_login') ??
                                          '验证并登录',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // 重新发送/修改邮箱
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_countdownSeconds > 0)
                                  Text(
                                    _countdownText,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: _sendCode,
                                    child: Text(
                                      loc?.translate('resend_code') ?? '重新发送',
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  "|",
                                  style: TextStyle(color: Colors.grey.shade300),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isCodeSent = false;
                                      _otpCode = '';
                                    });
                                  },
                                  child: Text(
                                    loc?.translate('change_email') ?? '修改邮箱',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 32),

                // 登录按钮 - 仅在密码模式下显示
                if (_loginMode == LoginMode.password)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithPassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            loc?.translate('login') ?? '登录',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                const SizedBox(height: 48),

                LoginLegalLinks(
                  agreementText:
                      loc?.translate('agree_terms') ?? '登录即表示您同意我们的服务条款和隐私政策',
                  privacyLabel: loc?.translate('privacy') ?? 'Privacy',
                  legalLabel: loc?.translate('account_data_legal') ?? 'Legal',
                  onOpenTerms: () => context.push('/docs/terms-of-service'),
                  onOpenPrivacy: () => context.push('/docs/privacy-policy'),
                  onOpenLegal: () => context.push('/docs/legal-restrictions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
