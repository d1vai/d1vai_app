import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import '../core/theme/locale_font_helper.dart';
import '../l10n/app_localizations.dart';
import '../utils/desktop_layout.dart';
import '../widgets/app_liquid_glass.dart';
import 'dashboard_screen.dart';
import 'community_screen.dart';
import 'docs_screen.dart';
import 'settings_screen.dart';

String _t(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context)?.translate(key);
  if (value == null || value == key) return fallback;
  return value;
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final String? settingsInitialTab;

  const MainScreen({super.key, this.initialIndex = 0, this.settingsInitialTab});

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
        icon: const Icon(Icons.home_rounded),
        inactiveIcon: const Icon(Icons.home_outlined),
        title: (loc?.translate('dashboard') ?? 'Dashboard'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.people_alt_rounded),
        inactiveIcon: const Icon(Icons.people_alt_outlined),
        title: (loc?.translate('community') ?? 'Community'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.menu_book_rounded),
        inactiveIcon: const Icon(Icons.menu_book_outlined),
        title: (loc?.translate('docs') ?? 'Docs'),
        activeColorPrimary: theme.colorScheme.primary,
        inactiveColorPrimary: theme.colorScheme.onSurface.withValues(
          alpha: 0.6,
        ),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings_rounded),
        inactiveIcon: const Icon(Icons.settings_outlined),
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
    final desktop = isDesktopLayout(context);
    final theme = Theme.of(context);
    final items = _navBarsItems(context);
    Widget content;
    if (desktop) {
      content = Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.digit1, meta: true): _NavIntent(0),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true): _NavIntent(1),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true): _NavIntent(2),
          SingleActivator(LogicalKeyboardKey.digit4, meta: true): _NavIntent(3),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _NavIntent: CallbackAction<_NavIntent>(
              onInvoke: (intent) {
                _handleTabSelected(intent.index);
                return null;
              },
            ),
          },
          child: Scaffold(
            body: Row(
              children: [
                _D1VDesktopSideNav(
                  items: items,
                  selectedIndex: _controller.index,
                  onItemSelected: _handleTabSelected,
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                    ),
                    child: IndexedStack(
                      index: _controller.index,
                      children: _buildScreens(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      const navBarHeight = 104.0;
      content = PersistentTabView.custom(
        context,
        controller: _controller,
        screens: _buildCustomScreens(),
        itemCount: items.length,
        bottomScreenMargin: 0,
        confineToSafeArea: true,
        backgroundColor: Colors.transparent,
        handleAndroidBackButtonPress: true,
        resizeToAvoidBottomInset: true,
        stateManagement: true,
        navBarHeight: navBarHeight,
        customWidget: _D1VBottomNavBar(
          items: items,
          selectedIndex: _controller.index,
          onItemSelected: _handleTabSelected,
        ),
      );
    }

    return GlassPage(
      background: desktop ? const _MainScreenDesktopBackdrop() : null,
      child: content,
    );
  }
}

class _NavIntent extends Intent {
  final int index;

  const _NavIntent(this.index);
}

class _D1VDesktopSideNav extends StatelessWidget {
  final List<PersistentBottomNavBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _D1VDesktopSideNav({
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 264,
      child: AppLiquidGlass(
        variant: AppLiquidGlassVariant.navigation,
        borderRadius: 0,
        quality: GlassQuality.premium,
        useOwnLayer: true,
        glowIntensity: isDark ? 0.18 : 0.08,
        settings: LiquidGlassSettings(
          blur: isDark ? 18 : 14,
          thickness: isDark ? 36 : 28,
          glassColor: Color.lerp(
            colorScheme.surface.withValues(alpha: isDark ? 0.18 : 0.22),
            colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
            0.3,
          )!,
          lightIntensity: isDark ? 0.28 : 0.34,
          saturation: isDark ? 1.18 : 1.10,
          glowIntensity: isDark ? 0.5 : 0.22,
          standardOpacityMultiplier: isDark ? 1.0 : 0.62,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface.withValues(alpha: isDark ? 0.22 : 0.28),
                colorScheme.surfaceContainerLow.withValues(
                  alpha: isDark ? 0.14 : 0.18,
                ),
              ],
            ),
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.58),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: isDark ? 0.12 : 0.06,
                ),
                blurRadius: 24,
                offset: const Offset(8, 0),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'd1v',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(context, 'main_nav_workspace', 'Workspace'),
                  style: LocaleFontHelper.localizedTitleStyle(
                    context,
                    theme.textTheme.bodyMedium,
                  )?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < items.length; i++) ...[
                  _D1VDesktopNavItem(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onItemSelected(i),
                  ),
                  const SizedBox(height: 8),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainScreenDesktopBackdrop extends StatelessWidget {
  const _MainScreenDesktopBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.10),
              colorScheme.surface,
            ),
            colorScheme.surfaceContainerLowest,
            Color.alphaBlend(
              colorScheme.tertiary.withValues(alpha: isDark ? 0.10 : 0.06),
              colorScheme.surface,
            ),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -140,
            top: -120,
            child: _BackdropBlob(
              size: 420,
              color: colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
          ),
          Positioned(
            left: 80,
            bottom: -160,
            child: _BackdropBlob(
              size: 360,
              color: colorScheme.tertiary.withValues(
                alpha: isDark ? 0.16 : 0.10,
              ),
            ),
          ),
          Positioned(
            right: -120,
            top: 80,
            child: _BackdropBlob(
              size: 320,
              color: colorScheme.secondary.withValues(
                alpha: isDark ? 0.10 : 0.08,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.58),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

class _D1VDesktopNavItem extends StatelessWidget {
  final PersistentBottomNavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _D1VDesktopNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = item.activeColorPrimary;
    final inactiveColor =
        item.inactiveColorPrimary ?? colorScheme.onSurfaceVariant;
    final icon = selected ? item.icon : (item.inactiveIcon ?? item.icon);
    final title = item.title ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : colorScheme.outlineVariant.withValues(alpha: 0.0),
            ),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  size: 22,
                  color: selected ? activeColor : inactiveColor,
                ),
                child: icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style:
                      LocaleFontHelper.localizedTitleStyle(
                        context,
                        theme.textTheme.titleSmall,
                      )?.copyWith(
                        color: selected ? activeColor : inactiveColor,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
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
    const tabWidth = 88.0;
    final screenWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal;
    final centeredHorizontalPadding = math.max(
      16.0,
      (screenWidth - (items.length * tabWidth)) / 2,
    );
    final selectedIconColor = isDark
        ? Colors.white
        : colorScheme.onSurface.withValues(alpha: 0.96);
    final unselectedIconColor = colorScheme.onSurfaceVariant.withValues(
      alpha: isDark ? 0.78 : 0.70,
    );

    return GlassBottomBar(
      tabs: items
          .map(
            (item) => GlassBottomBarTab(
              label: (item.title ?? '').trim().isEmpty ? null : item.title,
              icon: item.inactiveIcon ?? item.icon,
              activeIcon: item.icon,
              glowColor: item.activeColorPrimary.withValues(
                alpha: isDark ? 0.30 : 0.18,
              ),
              thickness: 0.8,
            ),
          )
          .toList(growable: false),
      selectedIndex: selectedIndex,
      onTabSelected: onItemSelected,
      quality: GlassQuality.premium,
      horizontalPadding: centeredHorizontalPadding,
      tabWidth: tabWidth,
      labelFontSize: 10,
      selectedIconColor: selectedIconColor,
      unselectedIconColor: unselectedIconColor,
      indicatorColor: colorScheme.primary.withValues(
        alpha: isDark ? 0.20 : 0.12,
      ),
      interactionBehavior: GlassInteractionBehavior.full,
      interactionGlowColor: colorScheme.primary.withValues(
        alpha: isDark ? 0.34 : 0.20,
      ),
      pressScale: 1.04,
      indicatorExpansion: 14,
      magnification: 1.08,
      glowBlurRadius: 36,
      glowSpreadRadius: 10,
      glowOpacity: isDark ? 0.72 : 0.48,
    );
  }
}
