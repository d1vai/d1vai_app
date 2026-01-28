import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/snackbar_helper.dart';
import '../l10n/app_localizations.dart';
import '../utils/error_utils.dart';

/// 登录模式枚举
enum LoginMode {
  code('code'),
  password('password'),
  wallet('wallet');

  const LoginMode(this.value);
  final String value;

  String getLabel(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) {
      // 使用英文作为默认回退，确保多语言一致性
      return switch (this) {
        code => 'Login with Code',
        password => 'Login with Password',
        wallet => 'Login with Wallet',
      };
    }
    return switch (this) {
      code => loc.translate('login_with_code'),
      password => loc.translate('login_with_password'),
      wallet => loc.translate('login_with_wallet'),
    };
  }

  static LoginMode fromString(String code) {
    return LoginMode.values.firstWhere(
      (mode) => mode.value == code,
      orElse: () => LoginMode.code,
    );
  }
}

enum WalletLoginChain {
  solana('Solana', 'SOL'),
  sui('Sui', 'SUI');

  const WalletLoginChain(this.label, this.symbol);
  final String label;
  final String symbol;
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
  final _walletAddressController = TextEditingController();
  final _walletSignatureController = TextEditingController();

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

  WalletLoginChain _walletChain = WalletLoginChain.solana;
  int _walletNonce = DateTime.now().millisecondsSinceEpoch;

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
    _walletAddressController.dispose();
    _walletSignatureController.dispose();
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
      if (mode == LoginMode.wallet) {
        _walletSignatureController.clear();
        _walletNonce = DateTime.now().millisecondsSinceEpoch;
      }
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

  String _buildWalletSignMessage(String walletAddress) {
    final address = walletAddress.trim().isEmpty ? '<address>' : walletAddress.trim();
    return 'Sign in to d1vai\\n'
        'wallet=$address\\n'
        'chain=${_walletChain.symbol}\\n'
        'nonce=$_walletNonce\\n'
        'This signature does NOT trigger any on-chain transaction.';
  }

  void _regenerateWalletNonce() {
    setState(() {
      _walletNonce = DateTime.now().millisecondsSinceEpoch;
      _walletSignatureController.clear();
    });
  }

  List<int> _parseSolanaSignature(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      throw const FormatException('Please paste your signature');
    }

    // 1) JSON array: [1,2,3,...]
    if (s.startsWith('[') && s.endsWith(']')) {
      final decoded = jsonDecode(s);
      if (decoded is! List) {
        throw const FormatException('Invalid signature JSON');
      }
      return decoded.map((e) => (e as num).toInt()).toList(growable: false);
    }

    // 2) Hex string: 0x... or ...
    final hex = s.startsWith('0x') ? s.substring(2) : s;
    final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
    if (isHex && hex.length.isEven) {
      final out = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        out.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return out;
    }

    // 3) Base64 string
    try {
      return base64Decode(s).toList(growable: false);
    } catch (_) {
      throw const FormatException(
        'Invalid signature format. Paste JSON bytes ([...]), hex, or base64.',
      );
    }
  }

  Future<void> _loginWithWallet() async {
    final address = _walletAddressController.text.trim();
    if (address.isEmpty) {
      _showError('Please enter a wallet address');
      return;
    }
    final signatureRaw = _walletSignatureController.text.trim();
    if (signatureRaw.isEmpty) {
      _showError('Please paste your signature');
      return;
    }

    final msg = _buildWalletSignMessage(address);
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (_walletChain == WalletLoginChain.solana) {
        final sig = _parseSolanaSignature(signatureRaw);
        await auth.loginWithSolanaWallet(
          walletAddress: address,
          message: msg,
          signature: sig,
        );
      } else {
        await auth.loginWithSuiWallet(
          walletAddress: address,
          message: msg,
          signature: signatureRaw,
        );
      }

      if (!mounted) return;
      _showSuccess(
        AppLocalizations.of(context)?.translate('login_success') ?? '登录成功',
      );
      context.go('/dashboard');
    } catch (e) {
      _showError(humanizeError(e));
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
                  _SessionExpiredBanner(
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
                              color: isSelected ? cs.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.10),
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
                                color: isSelected ? cs.primary : cs.onSurfaceVariant,
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

                // 邮箱输入（钱包登录不需要）
                if (_loginMode != LoginMode.wallet && !_isCodeSent)
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
                if (_loginMode == LoginMode.wallet) ...[
                  _buildWalletLoginCard(),
                ] else if (_loginMode == LoginMode.password) ...[
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
                if (_loginMode == LoginMode.wallet) ...[
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithWallet,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
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
                const SizedBox(height: 48),

                // 底部提示
                Text(
                  loc?.translate('agree_terms') ?? '登录即表示您同意我们的服务条款和隐私政策',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletLoginCard() {
    final theme = Theme.of(context);
    final msg = _buildWalletSignMessage(_walletAddressController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<WalletLoginChain>(
          key: ValueKey(_walletChain),
          initialValue: _walletChain,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Chain',
          ),
          items: WalletLoginChain.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.label),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _walletChain = v;
              _walletSignatureController.clear();
              _walletNonce = DateTime.now().millisecondsSinceEpoch;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _walletAddressController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Wallet address',
            hintText: '0x… / base58…',
          ),
          onChanged: (_) {
            // Changing address changes the signed payload; clear old signature.
            setState(() {
              _walletSignatureController.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(
            msg,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: msg));
                      if (!mounted) return;
                      SnackBarHelper.showSuccess(
                        context,
                        title: AppLocalizations.of(context)?.translate('copied') ??
                            'Copied',
                        message: 'Signing message copied',
                      );
                    },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy message'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isLoading ? null : _regenerateWalletNonce,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _walletSignatureController,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _walletChain == WalletLoginChain.solana
                ? 'Signature (JSON bytes / hex / base64)'
                : 'Signature',
            hintText: _walletChain == WalletLoginChain.solana
                ? 'Paste signature as: [1,2,...] or base64/hex'
                : 'Paste signature',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    final data = await Clipboard.getData('text/plain');
                    final text = (data?.text ?? '').trim();
                    if (text.isEmpty) {
                      if (!mounted) return;
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Paste',
                        message: 'Clipboard is empty',
                      );
                      return;
                    }
                    _walletSignatureController.text = text;
                    if (!mounted) return;
                    SnackBarHelper.showSuccess(
                      context,
                      title: 'Pasted',
                      message: 'Signature pasted',
                    );
                  },
            icon: const Icon(Icons.content_paste, size: 16),
            label: const Text('Paste signature'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tip: sign the message in your wallet app, then paste the signature here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SessionExpiredBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;

  const _SessionExpiredBanner({
    required this.title,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: cs.onErrorContainer)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: cs.onErrorContainer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
