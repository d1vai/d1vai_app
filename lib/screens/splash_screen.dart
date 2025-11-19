import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/onboarding_wizard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for AuthProvider to initialize
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Small delay for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      // 检查是否需要完成 onboarding
      if (authProvider.needsOnboarding) {
        _showOnboardingWizard();
      } else {
        context.go('/dashboard');
      }
    } else {
      // 未登录用户直接进入 Community 页面
      context.go('/community');
    }
  }

  /// 显示 Onboarding 向导
  void _showOnboardingWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OnboardingWizard(
        onCompleted: () {
          context.go('/dashboard');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'd1vai',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
