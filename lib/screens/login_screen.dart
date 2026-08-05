import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple_sign_in;
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/widgets/snackbar_helper.dart';
import 'package:d1vai_app/widgets/auth/login_legal_links.dart';
import 'package:d1vai_app/widgets/auth/session_expired_banner.dart';
import 'package:d1vai_app/widgets/auth/auth_input_fields.dart';
import 'package:d1vai_app/widgets/auth/auth_display_controls.dart';
import 'package:d1vai_app/widgets/share_sheet.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/utils/apple_sign_in_error.dart';
import '../utils/desktop_layout.dart';

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
  bool _showMoreLoginOptions = false;

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

  String get _postLoginDestination {
    final destination = GoRouterState.of(
      context,
    ).uri.queryParameters['redirect'];
    if (destination != null &&
        destination.startsWith('/') &&
        !destination.startsWith('//')) {
      return destination;
    }
    return '/dashboard';
  }

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
      if (mounted) context.go(_postLoginDestination);
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
      if (mounted) context.go(_postLoginDestination);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    final loc = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.stageInvitationCode(widget.inviteCode ?? '');
      await authProvider.loginWithApple();
      _showSuccess(loc?.translate('login_success') ?? '登录成功');
      if (mounted) context.go(_postLoginDestination);
    } catch (e) {
      if (isAppleSignInCancellation(e)) {
        if (mounted) {
          SnackBarHelper.showInfo(
            context,
            title:
                loc?.translate('apple_login_canceled_title') ??
                'Sign-in canceled',
            message:
                loc?.translate('apple_login_canceled_message') ??
                'You canceled Apple sign-in.',
          );
        }
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithOAuth(String provider) async {
    final loc = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.stageInvitationCode(widget.inviteCode ?? '');
      await authProvider.loginWithOAuth(
        provider: provider,
        inviteCode: widget.inviteCode,
      );
      _showSuccess(loc?.translate('login_success') ?? '登录成功');
      if (mounted) context.go(_postLoginDestination);
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
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

    if (!_isCodeSent) {
      return FilledButton.icon(
        onPressed: _isSendingCode || (_countdownSeconds < 60 && _isCodeSent)
            ? null
            : _sendCode,
        icon: _isSendingCode
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                ),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(
          _isSendingCode
              ? loc?.translate('sending') ?? '发送中...'
              : (_countdownSeconds < 60 && _isCodeSent
                    ? _countdownText
                    : (_isCodeSent
                          ? loc?.translate('resend_code') ?? '重新发送验证码'
                          : loc?.translate('login_continue') ?? 'Continue')),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: _primaryButtonStyle(context),
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
              child: Text(loc?.translate('login_change_email') ?? '修改邮箱'),
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

  Widget _buildAppleLoginButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: Opacity(
              opacity: _isLoading ? 0.72 : 1,
              child: apple_sign_in.SignInWithAppleButton(
                onPressed: _loginWithApple,
                text:
                    loc?.translate('login_with_apple') ?? 'Continue with Apple',
                height: 44,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                style: isDark
                    ? apple_sign_in.SignInWithAppleButtonStyle.whiteOutlined
                    : apple_sign_in.SignInWithAppleButtonStyle.black,
                iconAlignment: apple_sign_in.IconAlignment.left,
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOAuthButton({
    required String label,
    required VoidCallback onPressed,
    required Widget leading,
    Color? backgroundColor,
    Color? foregroundColor,
    BorderSide? side,
  }) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: _isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: side ?? BorderSide(color: cs.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Row(
        children: [
          SizedBox(width: 22, height: 22, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 22, height: 22),
        ],
      ),
    );
  }

  Widget _buildOAuthMarkBadge({
    required Widget child,
    Color? backgroundColor,
    BorderSide? side,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.84)
                : Colors.white),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color:
              side?.color ??
              cs.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.68),
          width: side?.width ?? 1,
        ),
      ),
      child: SizedBox(width: 22, height: 22, child: Center(child: child)),
    );
  }

  Widget _buildGoogleMark() {
    return _buildOAuthMarkBadge(
      child: SvgPicture.asset(
        'assets/auth/google-mark.svg',
        width: 16,
        height: 16,
      ),
    );
  }

  Widget _buildMicrosoftMark() {
    const tileSize = 8.0;
    const gap = 2.0;

    Widget square(Color color) {
      return Container(width: tileSize, height: tileSize, color: color);
    }

    return _buildOAuthMarkBadge(
      child: SizedBox(
        width: tileSize * 2 + gap,
        height: tileSize * 2 + gap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                square(const Color(0xFFF25022)),
                const SizedBox(width: gap),
                square(const Color(0xFF7FBA00)),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                square(const Color(0xFF00A4EF)),
                const SizedBox(width: gap),
                square(const Color(0xFFFFB900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGitHubMark() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = isDark ? Colors.white : const Color(0xFF111827);
    final iconColor = isDark ? const Color(0xFF111827) : Colors.white;

    return _buildOAuthMarkBadge(
      backgroundColor: badgeColor,
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.26)
            : const Color(0xFF111827),
      ),
      child: SvgPicture.asset(
        'assets/auth/github-mark.svg',
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildSocialLoginSection() {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;

    final googleButton = _buildOAuthButton(
      label: loc?.translate('login_with_google') ?? 'Sign in with Google',
      onPressed: () => _loginWithOAuth('google'),
      leading: _buildGoogleMark(),
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      side: BorderSide(color: cs.outlineVariant),
    );
    final secondaryButtons = <Widget>[
      if (isApplePlatform) googleButton,
      _buildOAuthButton(
        label: loc?.translate('login_with_github') ?? 'Sign in with GitHub',
        onPressed: () => _loginWithOAuth('github'),
        leading: _buildGitHubMark(),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant),
      ),
      _buildOAuthButton(
        label:
            loc?.translate('login_with_microsoft') ?? 'Sign in with Microsoft',
        onPressed: () => _loginWithOAuth('microsoft'),
        leading: _buildMicrosoftMark(),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                loc?.translate('or') ?? 'or',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: cs.outlineVariant)),
          ],
        ),
        const SizedBox(height: 14),
        if (isApplePlatform) _buildAppleLoginButton() else googleButton,
        TextButton.icon(
          onPressed: () =>
              setState(() => _showMoreLoginOptions = !_showMoreLoginOptions),
          icon: AnimatedRotation(
            turns: _showMoreLoginOptions ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ),
          label: Text(
            loc?.translate('login_more_options') ?? 'More sign-in options',
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < secondaryButtons.length; index++) ...[
                secondaryButtons[index],
                if (index < secondaryButtons.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
          crossFadeState: _showMoreLoginOptions
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }

  Widget _buildLoginModeAction(AppLocalizations? loc) {
    final usePassword = _loginMode == LoginMode.password;
    return Center(
      child: TextButton(
        onPressed: () =>
            _onModeChanged(usePassword ? LoginMode.code : LoginMode.password),
        child: Text(
          usePassword
              ? loc?.translate('login_with_code') ?? 'Login with Code'
              : loc?.translate('login_with_password') ?? 'Login with Password',
        ),
      ),
    );
  }

  Widget _buildInviteBanner(AppLocalizations? loc) {
    if ((widget.inviteCode ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final inviteCode = (widget.inviteCode ?? '').trim();
    final template =
        loc?.translate('login_invite_banner') ??
        'Invite code {code} will be applied after login.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        template.replaceAll('{code}', inviteCode),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations? loc, {required bool desktop}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSessionExpiredBanner) ...[
            SessionExpiredBanner(
              title:
                  loc?.translate('session_expired_title') ?? 'Session expired',
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
            _buildInviteBanner(loc),
            const SizedBox(height: 16),
          ],
          AuthTextInput(
            controller: _emailController,
            labelText: loc?.translate('email_address') ?? '邮箱地址',
            hintText: loc?.translate('enter_email') ?? '请输入您的邮箱',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
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
          const SizedBox(height: 18),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: KeyedSubtree(
              key: ValueKey(_loginMode),
              child: _loginMode == LoginMode.code
                  ? _buildCodeModeContent(loc)
                  : _buildPasswordModeContent(loc),
            ),
          ),
          const SizedBox(height: 6),
          _buildLoginModeAction(loc),
          const SizedBox(height: 10),
          _buildSocialLoginSection(),
          const SizedBox(height: 24),
          Text(
            loc?.translate('login_auto_register_hint') ??
                'Continuing signs you in. New accounts are created automatically.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          LoginLegalLinks(
            agreementText:
                loc?.translate('agree_terms') ?? '登录即表示您同意我们的服务条款和隐私政策',
            legalLabel: loc?.translate('account_data_legal') ?? 'Legal',
            onOpenLegal: () => context.push(
              ShareLinks.docsBySlug(
                'privacy-policy',
                hideHeader: true,
              ).toString(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final desktop = isDesktopLayout(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: ColoredBox(
        color: cs.surface,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: desktop
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 72, 32, 40),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _buildLoginForm(loc, desktop: true),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 700;
                          final horizontalPadding = constraints.maxWidth < 360
                              ? 16.0
                              : 24.0;
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              compact ? 64 : 80,
                              horizontalPadding,
                              compact ? 20 : 32,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: _buildLoginForm(loc, desktop: false),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Positioned(top: 8, right: 12, child: AuthDisplayControls()),
            ],
          ),
        ),
      ),
    );
  }
}
