import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/onboarding_wizard.dart';

/// Onboarding 页面 - 用于引导用户完成初始设置
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OnboardingWizard(
          onCompleted: () {
            // Onboarding 完成后的处理
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );

            // 检查是否还有用户数据
            if (authProvider.user != null) {
              // 跳转到 dashboard
              context.go('/dashboard');
            } else {
              // 如果没有用户数据，返回登录页
              context.go('/login');
            }
          },
        ),
      ),
    );
  }
}
