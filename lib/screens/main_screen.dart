import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart';
import 'community_screen.dart';
import 'docs_screen.dart';
import 'settings_screen.dart';
import 'order_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: widget.initialIndex);
  }

  List<Widget> _buildScreens() {
    return [
      const DashboardScreen(),
      const CommunityScreen(),
      const DocsScreen(),
      const OrderScreen(),
      const SettingsScreen(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      PersistentBottomNavBarItem(
        icon: Icon(PhosphorIcons.house()),
        title: (loc?.translate('dashboard') ?? 'Dashboard'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: Icon(PhosphorIcons.users()),
        title: (loc?.translate('community') ?? 'Community'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: Icon(PhosphorIcons.book()),
        title: (loc?.translate('docs') ?? 'Docs'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: Icon(PhosphorIcons.receipt()),
        title: 'Orders',
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: Icon(PhosphorIcons.gear()),
        title: (loc?.translate('settings') ?? 'Settings'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(context),
      confineToSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      decoration: NavBarDecoration(
        borderRadius: BorderRadius.circular(10.0),
        colorBehindNavBar: theme.colorScheme.surface,
      ),
      navBarStyle: NavBarStyle.style1,
    );
  }
}
