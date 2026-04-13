import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';
import 'package:d1vai_app/widgets/auth/login_legal_links.dart';
import 'package:d1vai_app/widgets/auth/session_expired_banner.dart';
import 'package:d1vai_app/widgets/auth/auth_input_fields.dart';
import 'package:d1vai_app/widgets/auth/auth_display_controls.dart';
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

// ─── 独立的 Tab 切换栏，避免父级 setState 时重建 ───────────────────────────────
class _LoginModeTabBar extends StatelessWidget {
  final LoginMode selected;
  final ValueChanged<LoginMode> onChanged;

  const _LoginModeTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: isDark ? 0.28 : 0.14),
            cs.tertiary.withValues(alpha: isDark ? 0.2 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.48 : 0.72),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: selected == LoginMode.code
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: isDark ? 0.88 : 0.96),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.55 : 0.85,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        blurRadius: isDark ? 8 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: LoginMode.values.map((mode) {
              final isSelected = mode == selected;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    onTap: () => onChanged(mode),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        ),
                        child: Text(
                          mode.getLabel(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool sessionExpired;
  final String? inviteCode;

  const LoginScreen({super.key, this.sessionExpired = false, this.inviteCode});

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
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  /// 启动倒计时定时器
  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  /// 处理模式切换 —— 只更新 _loginMode，不重置验证码状态
  void _onModeChanged(LoginMode mode) {
    if (_loginMode == mode) return;
    setState(() {
      _loginMode = mode;
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.stageInvitationCode(widget.inviteCode ?? '');
      await authProvider.verifyCodeAndLogin(
        _emailController.text.trim(),
        _otpCode,
      );
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.stageInvitationCode(widget.inviteCode ?? '');
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
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

  ButtonStyle _primaryButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      disabledBackgroundColor: cs.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.9 : 1,
      ),
      disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.72),
      elevation: 0,
    );
  }

  // ─── 验证码模式内容 ────────────────────────────────────────────────────────
  Widget _buildCodeModeContent(AppLocalizations? loc) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (!_isCodeSent) {
      final bgGradient = LinearGradient(
        colors: [
          cs.primary.withValues(alpha: isDark ? 0.2 : 0.08),
          cs.tertiary.withValues(alpha: isDark ? 0.16 : 0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: bgGradient,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.62 : 0.85),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: FilledButton.tonalIcon(
          onPressed: _isSendingCode || (_countdownSeconds < 60 && _isCodeSent)
              ? null
              : _sendCode,
          icon: _isSendingCode
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                )
              : Icon(Icons.send_outlined, size: 18, color: cs.primary),
          label: Text(
            _isSendingCode
                ? loc?.translate('sending') ?? '发送中...'
                : (_countdownSeconds < 60 && _isCodeSent
                      ? _countdownText
                      : (_isCodeSent
                            ? loc?.translate('resend_code') ?? '重新发送验证码'
                            : loc?.translate('send_code') ?? '发送验证码')),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: cs.surface.withValues(alpha: isDark ? 0.8 : 0.94),
            foregroundColor: cs.primary,
            disabledBackgroundColor: cs.surface.withValues(
              alpha: isDark ? 0.45 : 0.84,
            ),
            disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
            elevation: 0,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${loc?.translate('code_sent_to') ?? '验证码已发送至'} ${_emailController.text.trim()}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AuthOtpInput(
          count: 6,
          onCompleted: _onOtpCompleted,
          onChanged: _onOtpChanged,
          autoSubmit: true,
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: _isLoading ? null : _loginWithCode,
          style: _primaryButtonStyle(context),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  ),
                )
              : Text(
                  loc?.translate('verify_and_login') ?? '验证并登录',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_countdownSeconds > 0)
              Text(
                _countdownText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              TextButton(
                onPressed: _sendCode,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(loc?.translate('resend_code') ?? '重新发送'),
              ),
            const SizedBox(width: 8),
            Text(
              '|',
              style: TextStyle(color: cs.outlineVariant.withValues(alpha: 0.9)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isCodeSent = false;
                  _otpCode = '';
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: Text(loc?.translate('change_email') ?? '修改邮箱'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 密码模式内容 ──────────────────────────────────────────────────────────
  Widget _buildPasswordModeContent(AppLocalizations? loc) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextInput(
          controller: _passwordController,
          labelText: loc?.translate('password') ?? '密码',
          hintText: loc?.translate('enter_password') ?? '请输入密码',
          icon: Icons.lock_outline,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return loc?.translate('password_required') ?? '请输入密码';
            }
            return null;
          },
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _isLoading ? null : _loginWithPassword,
          style: _primaryButtonStyle(context),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  ),
                )
              : Text(
                  loc?.translate('login') ?? '登录',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: AuthDisplayControls(),
                ),
                const SizedBox(height: 40),
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
                if ((widget.inviteCode ?? '').trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Invite code ${(widget.inviteCode ?? '').trim()} will be applied after login.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

                // 模式切换标签 —— 独立 Widget，不受父级 setState 影响
                _LoginModeTabBar(
                  selected: _loginMode,
                  onChanged: _onModeChanged,
                ),
                const SizedBox(height: 32),

                // 邮箱输入 —— 始终存在，避免切换 tab 时布局跳动
                AuthTextInput(
                  controller: _emailController,
                  labelText: loc?.translate('email_address') ?? '邮箱地址',
                  hintText: loc?.translate('enter_email') ?? '请输入您的邮箱',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
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

                // 用 IndexedStack 保持两个模式的子树，切换时不销毁/重建
                IndexedStack(
                  index: _loginMode.index,
                  children: [
                    // index 0 → code 模式
                    _buildCodeModeContent(loc),
                    // index 1 → password 模式
                    _buildPasswordModeContent(loc),
                  ],
                ),

                const SizedBox(height: 48),

                LoginLegalLinks(
                  agreementText:
                      loc?.translate('agree_terms') ?? '登录即表示您同意我们的服务条款和隐私政策',
                  legalLabel: loc?.translate('account_data_legal') ?? 'Legal',
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
