import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/app_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/language_settings_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/realtime_analytics_screen.dart';
import '../screens/invites_list_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/github_settings_screen.dart';
import '../providers/auth_provider.dart';

Page<dynamic> _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

GoRouter createAppRouter(BuildContext context) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final needsOnboarding = authProvider.needsOnboarding;

      final isLoginPage = state.matchedLocation == '/login';
      final isSplashPage = state.matchedLocation == '/';
      final isOnboardingPage = state.matchedLocation == '/onboarding';

      // 如果正在加载，保持在当前页面
      if (isLoading && !isSplashPage) {
        return null;
      }

      // 如果未登录且不在登录页，重定向到登录页
      if (!isAuthenticated && !isLoginPage && !isSplashPage) {
        return '/login';
      }

      // 如果已登录且需要完成 onboarding，且不在 onboarding 页面，重定向到 onboarding
      if (isAuthenticated && needsOnboarding && !isOnboardingPage) {
        return '/onboarding';
      }

      // 如果已登录且已完成 onboarding，且在 onboarding 页面，重定向到 dashboard
      if (isAuthenticated && !needsOnboarding && isOnboardingPage) {
        return '/dashboard';
      }

      // 如果已登录且在登录页，重定向到 dashboard
      if (isAuthenticated && isLoginPage) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const LoginScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const MainScreen(initialIndex: 0)),
      ),
      GoRoute(
        path: '/community',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const MainScreen(initialIndex: 1)),
      ),
      GoRoute(
        path: '/docs',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const MainScreen(initialIndex: 2)),
      ),
      GoRoute(
        path: '/orders',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const MainScreen(initialIndex: 3)),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const MainScreen(initialIndex: 4)),
      ),
      GoRoute(
        path: '/settings/language',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const LanguageSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/invites',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const InvitesListScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const NotificationSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/help',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const HelpSupportScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/github',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const GithubSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/projects/new',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const Scaffold(body: Center(child: Text('New Project Screen'))),
        ),
      ),
      GoRoute(
        path: '/projects/:id',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          ProjectDetailScreen(projectId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/projects/:id/chat',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          ChatScreen(
            projectId: state.pathParameters['id']!,
            autoprompt: state.uri.queryParameters['autoprompt'],
          ),
        ),
      ),
      GoRoute(
        path: '/projects/:id/analytics/realtime',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          RealtimeAnalyticsScreen(projectId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/apps/:slug',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          AppDetailScreen(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const ProfileScreen()),
      ),
      GoRoute(
        path: '/pricing',
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const PricingScreen()),
      ),
    ],
  );
}
