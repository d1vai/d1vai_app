import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import 'core/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/editor_preferences_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/project_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/macos_menu_controller.dart';
import 'router/app_router.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/auth_expiry_bus.dart';
import 'services/apple_iap_service.dart';
import 'services/app_analytics_service.dart';
import 'services/macos_folder_import_service.dart';
import 'services/macos_open_service.dart';
import 'services/stripe_payment_service.dart';
import 'package:url_launcher/url_launcher.dart';

final _appRouter = createAppRouter();
final _macosOpenService = MacosOpenService.instance;
final _macosFolderImportService = MacosFolderImportService.instance;
final _macosMenuController = MacosMenuController();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await ApiClient.ensureInitialized();
  } catch (e, st) {
    debugPrint('ApiClient initialization failed: $e');
    debugPrintStack(stackTrace: st);
  }

  await AppAnalyticsService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => EditorPreferencesProvider()),
        ChangeNotifierProvider.value(value: _macosMenuController),
        ChangeNotifierProvider.value(value: _macosOpenService),
        ChangeNotifierProvider.value(value: _macosFolderImportService),
      ],
      child: const _AuthExpiryGate(child: MyApp()),
    ),
  );

  unawaited(_macosOpenService.initialize());
  unawaited(_macosMenuController.load());

  unawaited(AppleIapService.ensureInitialized());
  unawaited(StripePaymentService.initialize());

  Future.delayed(const Duration(seconds: 1), () {
    FlutterNativeSplash.remove();
  });
}

@immutable
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocaleProvider, ThemeProvider, MacosMenuController>(
      builder: (context, localeProvider, themeProvider, menuController, child) {
        Widget app = MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'd1vai',
          builder: (context, child) {
            return _MacosImportListener(
              child: child ?? const SizedBox.shrink(),
            );
          },
          locale: localeProvider.locale,
          themeMode: themeProvider.flutterThemeMode,
          supportedLocales: LocaleProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(localeProvider.locale),
          darkTheme: AppTheme.dark(localeProvider.locale),
          routerConfig: _appRouter,
        );

        final isMacos =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
        if (!isMacos) return app;

        return PlatformMenuBar(
          menus: _buildMacosMenus(context, menuController),
          child: app,
        );
      },
    );
  }

  List<PlatformMenuItem> _buildMacosMenus(
    BuildContext context,
    MacosMenuController menuController,
  ) {
    final recentMenus = menuController.recentProjects.isEmpty
        ? <PlatformMenuItem>[
            const PlatformMenuItem(label: 'No Recent Projects'),
          ]
        : menuController.recentProjects
              .map(
                (item) => PlatformMenuItem(
                  label: item.name,
                  onSelected: () => _appRouter.push('/projects/${item.id}'),
                ),
              )
              .toList(growable: false);

    final recentProjectMenuItems = menuController.recentProjects.isEmpty
        ? recentMenus
        : <PlatformMenuItem>[
            ...recentMenus,
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Clear Recent Projects',
                  onSelected: () =>
                      unawaited(menuController.clearRecentProjects()),
                ),
              ],
            ),
          ];

    return <PlatformMenuItem>[
      PlatformMenu(
        label: 'File',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'New Project',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyN,
              meta: true,
            ),
            onSelected: () => _appRouter.push('/projects?create=1'),
          ),
          PlatformMenu(label: 'Recent Projects', menus: recentProjectMenuItems),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenuItem(
                label: 'Refresh Projects',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  meta: true,
                  shift: true,
                ),
                onSelected: () async {
                  final ctx =
                      _appRouter.routerDelegate.navigatorKey.currentContext;
                  if (ctx == null) return;
                  await Provider.of<ProjectProvider>(
                    ctx,
                    listen: false,
                  ).refresh();
                },
              ),
              PlatformMenuItem(
                label: 'Projects',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyP,
                  meta: true,
                ),
                onSelected: () => _appRouter.go('/projects'),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: 'Go',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Dashboard',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.digit1,
              meta: true,
            ),
            onSelected: () => _appRouter.go('/'),
          ),
          PlatformMenuItem(
            label: 'Community',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.digit2,
              meta: true,
            ),
            onSelected: () => _appRouter.go('/community'),
          ),
          PlatformMenuItem(
            label: 'Docs',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.digit3,
              meta: true,
            ),
            onSelected: () => _appRouter.go('/docs'),
          ),
          PlatformMenuItem(
            label: 'Settings',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.digit4,
              meta: true,
            ),
            onSelected: () => _appRouter.go('/settings'),
          ),
        ],
      ),
      PlatformMenu(
        label: 'Window',
        menus: <PlatformMenuItem>[
          if (PlatformProvidedMenuItem.hasMenu(
            PlatformProvidedMenuItemType.minimizeWindow,
          ))
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
          if (PlatformProvidedMenuItem.hasMenu(
            PlatformProvidedMenuItemType.zoomWindow,
          ))
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          if (PlatformProvidedMenuItem.hasMenu(
            PlatformProvidedMenuItemType.toggleFullScreen,
          ))
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
        ],
      ),
      PlatformMenu(
        label: 'Project',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Open Overview',
            onSelected: menuController.hasCurrentProject
                ? () => _appRouter.go(
                    '/projects/${menuController.currentProjectId}?tab=overview',
                  )
                : null,
          ),
          PlatformMenuItem(
            label: 'Open Chat',
            onSelected: menuController.hasCurrentProject
                ? () => _appRouter.go(
                    '/projects/${menuController.currentProjectId}?tab=chat',
                  )
                : null,
          ),
          PlatformMenuItem(
            label: 'Open Environment',
            onSelected: menuController.hasCurrentProject
                ? () => _appRouter.go(
                    '/projects/${menuController.currentProjectId}?tab=environment',
                  )
                : null,
          ),
          PlatformMenuItem(
            label: 'Open Database',
            onSelected: menuController.hasCurrentProject
                ? () => _appRouter.go(
                    '/projects/${menuController.currentProjectId}?tab=database',
                  )
                : null,
          ),
          PlatformMenuItem(
            label: 'Open Deploy',
            onSelected: menuController.hasCurrentProject
                ? () => _appRouter.go(
                    '/projects/${menuController.currentProjectId}?tab=deployment',
                  )
                : null,
          ),
        ],
      ),
      PlatformMenu(
        label: 'Help',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Docs',
            onSelected: () => _appRouter.go('/docs'),
          ),
          PlatformMenuItem(
            label: 'API Settings',
            onSelected: () => _appRouter.go('/settings/api'),
          ),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenuItem(
                label: 'Report Issue',
                onSelected: () => unawaited(
                  _launchMacosMenuUri(
                    Uri(
                      scheme: 'mailto',
                      path: 'support@d1v.ai',
                      query: 'subject=Issue Report',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

Future<void> _launchMacosMenuUri(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class _MacosImportListener extends StatefulWidget {
  final Widget child;

  const _MacosImportListener({required this.child});

  @override
  State<_MacosImportListener> createState() => _MacosImportListenerState();
}

class _MacosImportListenerState extends State<_MacosImportListener> {
  bool _draining = false;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = context.watch<MacosOpenService>().pendingImportPath;
    if (pending == null || pending.isEmpty || _draining) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draining) return;
      unawaited(_drainPendingImports());
    });
  }

  Future<void> _drainPendingImports() async {
    _draining = true;
    try {
      while (mounted) {
        final pendingPath = _macosOpenService.consumePendingImportPath();
        if (pendingPath == null || pendingPath.isEmpty) break;
        final navigatorContext =
            _appRouter.routerDelegate.navigatorKey.currentContext;
        if (navigatorContext == null) {
          debugPrint(
            '[d1vai-drop] missing navigator context for path=$pendingPath',
          );
          _macosOpenService.enqueueImportPath(pendingPath);
          break;
        }
        await _macosFolderImportService.importPath(
          navigatorContext,
          pendingPath,
        );
      }
    } finally {
      _draining = false;
      if (mounted) {
        final pending = _macosOpenService.pendingImportPath;
        if (pending != null && pending.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _draining) return;
            unawaited(_drainPendingImports());
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMacos = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    if (!isMacos) return widget.child;

    return DropTarget(
      onDragEntered: (_) {
        if (!mounted) return;
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (_) {
        if (!mounted) return;
        setState(() {
          _dragging = false;
        });
      },
      onDragDone: (detail) {
        if (!mounted) return;
        setState(() {
          _dragging = false;
        });
        for (final file in detail.files) {
          final path = file.path.trim();
          if (path.isEmpty) continue;
          debugPrint('[d1vai-drop] desktop_drop onDragDone path=$path');
          _macosOpenService.enqueueImportPath(path);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            ignoring: !_dragging,
            child: AnimatedOpacity(
              opacity: _dragging ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: _FlutterDropOverlay(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlutterDropOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_upload_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Drop folder or file to import',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Imports to cloud, then opens Code chat',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthExpiryGate extends StatefulWidget {
  final Widget child;

  const _AuthExpiryGate({required this.child});

  @override
  State<_AuthExpiryGate> createState() => _AuthExpiryGateState();
}

class _AuthExpiryGateState extends State<_AuthExpiryGate> {
  StreamSubscription<AuthExpiredEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AuthExpiryBus.stream.listen((event) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();
      _appRouter.go('/login?expired=1');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
