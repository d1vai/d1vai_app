import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? ordersInitialTab;
  final String? settingsInitialTab;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.ordersInitialTab,
    this.settingsInitialTab,
  });

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
      OrderScreen(initialTab: widget.ordersInitialTab),
      SettingsScreen(initialTab: widget.settingsInitialTab),
    ];
  }

  List<CustomNavBarScreen> _buildCustomScreens() {
    return _buildScreens()
        .map((screen) => CustomNavBarScreen(screen: screen))
        .toList();
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
        title: (loc?.translate('orders_title') ?? 'Orders'),
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

  void _handleTabSelected(int index) {
    final isSameTab = index == _controller.index;
    if (isSameTab) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _controller.index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _navBarsItems(context);
    return PersistentTabView.custom(
      context,
      controller: _controller,
      screens: _buildCustomScreens(),
      itemCount: items.length,
      confineToSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      navBarHeight: 78,
      customWidget: _D1VBottomNavBar(
        items: items,
        selectedIndex: _controller.index,
        onItemSelected: _handleTabSelected,
      ),
    );
  }
}

class _D1VBottomNavBar extends StatelessWidget {
  final List<PersistentBottomNavBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _D1VBottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    const outerPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

    return SafeArea(
      top: false,
      child: Padding(
        padding: outerPadding,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.72 : 0.9,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: isDark ? 0.24 : 0.1,
                ),
                blurRadius: isDark ? 18 : 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width / items.length;
              final indicatorWidth = itemWidth - 12;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: selectedIndex * itemWidth + 6,
                    top: 6,
                    bottom: 6,
                    width: indicatorWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(
                              alpha: isDark ? 0.28 : 0.12,
                            ),
                            colorScheme.primary.withValues(
                              alpha: isDark ? 0.16 : 0.06,
                            ),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: colorScheme.primary.withValues(
                            alpha: isDark ? 0.4 : 0.14,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: isDark ? 0.18 : 0.08,
                            ),
                            blurRadius: isDark ? 18 : 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _D1VBottomNavItem(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onItemSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _D1VBottomNavItem extends StatefulWidget {
  final PersistentBottomNavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _D1VBottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_D1VBottomNavItem> createState() => _D1VBottomNavItemState();
}

class _D1VBottomNavItemState extends State<_D1VBottomNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final selected = widget.selected;
    final activeColor = item.activeColorPrimary;
    final inactiveColor =
        item.inactiveColorPrimary ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    final title = item.title ?? '';
    final icon = selected ? item.icon : (item.inactiveIcon ?? item.icon);

    return AnimatedBuilder(
      animation: _pressScale,
      builder: (context, child) {
        return Transform.scale(scale: _pressScale.value, child: child);
      },
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _pressController.forward(),
            onTapCancel: () => _pressController.reverse(),
            onTapUp: (_) => _pressController.reverse(),
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: selected ? const Offset(0, -0.08) : Offset.zero,
                    child: IconTheme(
                      data: IconThemeData(
                        size: 24,
                        color: selected ? activeColor : inactiveColor,
                      ),
                      child: icon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: selected ? activeColor : inactiveColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
