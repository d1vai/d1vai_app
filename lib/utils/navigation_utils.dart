import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationUtils {
  const NavigationUtils._();

  static void popOrGo(BuildContext context, String fallbackRoute) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    router.go(fallbackRoute);
  }
}
