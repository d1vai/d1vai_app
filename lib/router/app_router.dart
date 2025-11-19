import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';

import '../screens/main_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/app_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/pricing_screen.dart';

Page<dynamic> _buildPageWithTransition(BuildContext context, GoRouterState state, Widget child) {
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

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const LoginScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const MainScreen()),
    ),
    GoRoute(
      path: '/projects/new',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const Scaffold(body: Center(child: Text('New Project Screen')))),
    ),
    GoRoute(
      path: '/projects/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, ProjectDetailScreen(projectId: state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/apps/:slug',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, AppDetailScreen(slug: state.pathParameters['slug']!)),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const ProfileScreen()),
    ),
    GoRoute(
      path: '/pricing',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const PricingScreen()),
    ),
  ],
);
