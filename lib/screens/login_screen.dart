import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_field.dart';

/// 登录模式枚举
enum LoginMode {
  code('code', '验证码登录'),
  password('password', '密码登录');

  const LoginMode(this.value, this.label);
  final String value;
  final String label;

  static LoginMode fromString(String code) {
    return LoginMode.values.firstWhere(
      (mode) => mode.value == code,
      orElse: () => LoginMode.code,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _countdownText = '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 启动倒计时定时器
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _countdownText = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _countdownSeconds--;
            _countdownText = '$_countdownSeconds秒后重发';
          });
        }
      }
    });
  }

  /// 重置倒计时
  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 60;
    setState(() {
      _countdownText = '60秒后重发';
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
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: '登录失败',
        message: message,
        contentType: ContentType.failure,
      ),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: '成功',
        message: message,
        contentType: ContentType.success,
      ),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// 验证码登录
  Future<void> _loginWithCode() async {
    if (_emailController.text.isEmpty) {
      _showError('请输入邮箱地址');
      return;
    }
    if (_otpCode.length != 6) {
      _showError('请输入完整的验证码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).verifyCodeAndLogin(_emailController.text.trim(), _otpCode);
      _showSuccess('登录成功');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 密码登录
  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(_emailController.text.trim(), _passwordController.text);
      _showSuccess('登录成功');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    if (_emailController.text.isEmpty) {
      _showError('请输入邮箱地址');
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
      _showSuccess('验证码已发送，请查收邮件');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: LoginMode.values.map((mode) {
                      final isSelected = mode == _loginMode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onModeChanged(mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // 邮箱输入
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱地址',
                    hintText: '请输入您的邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入邮箱地址';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return '请输入有效的邮箱地址';
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
                    decoration: const InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  // 验证码登录
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        (_countdownSeconds < 60 && _isCodeSent)
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
                                      ? '发送中...'
                                      : (_countdownSeconds < 60 && _isCodeSent
                                            ? _countdownText
                                            : (_isCodeSent
                                                  ? '重新发送验证码'
                                                  : '发送验证码')),
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
                      const SizedBox(height: 20),

                      // 验证码输入框 - 只有发送后才显示
                      if (_isCodeSent) ...[
                        const Text(
                          '请输入验证码',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SimpleOtpInput(
                          count: 6,
                          onCompleted: _onOtpCompleted,
                          onChanged: _onOtpChanged,
                        ),
                        const SizedBox(height: 16),

                        // 发送状态提示
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '验证码已发送至 ${_emailController.text.trim()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 32),

                // 登录按钮 - 只有在密码模式或已发送验证码时才显示
                if (_loginMode == LoginMode.password || _isCodeSent)
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_loginMode == LoginMode.password) {
                              _loginWithPassword();
                            } else {
                              _loginWithCode();
                            }
                          },
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
                            _loginMode == LoginMode.password ? '登录' : '验证登录',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                const SizedBox(height: 48),

                // 底部提示
                const Text(
                  '登录即表示您同意我们的服务条款和隐私政策',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
