import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import 'core/api_client.dart';
import 'models/desktop_window_launch_configuration.dart';
import 'providers/auth_provider.dart';
import 'providers/editor_preferences_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/macos_menu_controller.dart';
import 'router/app_router.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/auth_expiry_bus.dart';
import 'screens/desktop_workspace_welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/local_workspace_screen.dart';
import 'services/apple_iap_service.dart';
import 'services/app_analytics_service.dart';
import 'services/desktop_window_service.dart';
import 'services/macos_folder_import_service.dart';
import 'services/macos_open_service.dart';
import 'services/stripe_payment_service.dart';
import 'package:url_launcher/url_launcher.dart';

final _appRouter = createAppRouter();
final _macosOpenService = MacosOpenService.instance;
final _macosFolderImportService = MacosFolderImportService.instance;
final _macosMenuController = MacosMenuController();

void _scheduleSplashRemoval({Duration delay = Duration.zero}) {
  void removeSplash() {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  }

  if (delay > Duration.zero) {
    Future.delayed(delay, removeSplash);
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    removeSplash();
  });
}

Future<void> main([List<String> args = const <String>[]]) async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final launchConfiguration = DesktopWindowLaunchConfiguration.fromArgs(args);

  if (launchConfiguration.opensWorkspaceWindow) {
    ApiClient.setRuntimeLogScope('workspace/bootstrap');
    await _macosOpenService.initialize();
    _runWorkspaceWindowApp(
      initialRequest: launchConfiguration.workspaceRequest,
    );
    unawaited(_macosMenuController.load());
    _scheduleSplashRemoval();
    return;
  }

  ApiClient.setRuntimeLogScope('main/bootstrap');

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

  _scheduleSplashRemoval(delay: const Duration(seconds: 1));
}

@pragma('vm:entry-point')
Future<void> workspaceMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.setRuntimeLogScope('workspace/bootstrap');
  await _macosOpenService.initialize();
  _runWorkspaceWindowApp();

  unawaited(_macosMenuController.load());
  _scheduleSplashRemoval();
}

void _runWorkspaceWindowApp({DesktopWorkspaceLaunchRequest? initialRequest}) {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => EditorPreferencesProvider()),
        ChangeNotifierProvider.value(value: _macosMenuController),
        ChangeNotifierProvider.value(value: _macosOpenService),
        ChangeNotifierProvider.value(value: _macosFolderImportService),
      ],
      child: WorkspaceWindowApp(initialRequest: initialRequest),
    ),
  );
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

        return Consumer<MacosOpenService>(
          child: app,
          builder: (context, openService, child) {
            final hostIdentifier = openService.currentHostIdentifier;
            if (hostIdentifier != 'main') {
              return child ?? const SizedBox.shrink();
            }
            return PlatformMenuBar(
              menus: _buildMacosMenus(context, menuController, openService),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  List<PlatformMenuItem> _buildMacosMenus(
    BuildContext context,
    MacosMenuController menuController,
    MacosOpenService openService,
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

    final recentWorkspaceMenus = menuController.recentWorkspaces.isEmpty
        ? <PlatformMenuItem>[
            const PlatformMenuItem(label: 'No Recent Workspaces'),
          ]
        : menuController.recentWorkspaces
              .map(
                (item) => PlatformMenuItem(
                  label: item.label,
                  onSelected: () => unawaited(
                    _openLocalWorkspacePath(
                      item.path,
                      source: MacosOpenRequestSource.recentWorkspace,
                      preferNewWindow: true,
                    ),
                  ),
                ),
              )
              .toList(growable: false);

    final recentWorkspaceMenuItems = menuController.recentWorkspaces.isEmpty
        ? recentWorkspaceMenus
        : <PlatformMenuItem>[
            ...recentWorkspaceMenus,
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Clear Recent Workspaces',
                  onSelected: () =>
                      unawaited(menuController.clearRecentWorkspaces()),
                ),
              ],
            ),
          ];

    final currentHostIdentifier = openService.currentHostIdentifier;
    final openWorkspaceWindowMenus = openService.workspaceWindows.isEmpty
        ? <PlatformMenuItem>[
            const PlatformMenuItem(label: 'No Open Workspaces'),
          ]
        : openService.workspaceWindows
              .map(
                (item) => PlatformMenuItem(
                  label: item.hostIdentifier == currentHostIdentifier
                      ? '${item.displayTitle} (Current)'
                      : item.displayTitle,
                  onSelected: item.hostIdentifier == currentHostIdentifier
                      ? null
                      : () => unawaited(
                          openService.activateWorkspaceWindow(
                            item.hostIdentifier,
                          ),
                        ),
                ),
              )
              .toList(growable: false);

    return <PlatformMenuItem>[
      PlatformMenu(
        label: 'File',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Open Folder...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              meta: true,
            ),
            onSelected: () =>
                unawaited(_openLocalWorkspaceFromPicker(pickDirectory: true)),
          ),
          PlatformMenuItem(
            label: 'Open File...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              meta: true,
              shift: true,
            ),
            onSelected: () =>
                unawaited(_openLocalWorkspaceFromPicker(pickDirectory: false)),
          ),
          PlatformMenu(
            label: 'Recent Workspaces',
            menus: recentWorkspaceMenuItems,
          ),
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
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenu(
                label: 'Open Workspaces',
                menus: openWorkspaceWindowMenus,
              ),
            ],
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

class WorkspaceWindowApp extends StatefulWidget {
  final DesktopWorkspaceLaunchRequest? initialRequest;

  const WorkspaceWindowApp({super.key, this.initialRequest});

  @override
  State<WorkspaceWindowApp> createState() => _WorkspaceWindowAppState();
}

class _WorkspaceWindowAppState extends State<WorkspaceWindowApp> {
  late final String _initialLocation = _buildInitialLocation();
  late final GoRouter _router = GoRouter(
    initialLocation: _initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _WorkspaceWindowBootstrap(initialRequest: widget.initialRequest),
      ),
      GoRoute(
        path: '/local-workspace',
        builder: (context, state) => LocalWorkspaceScreen(
          requestedPath: state.uri.queryParameters['path'],
          source: state.uri.queryParameters['source'],
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          sessionExpired: state.uri.queryParameters['expired'] == '1',
          inviteCode: state.uri.queryParameters['invite'],
        ),
      ),
    ],
  );

  String _buildInitialLocation() {
    final launchRequest = widget.initialRequest;
    if (launchRequest != null && launchRequest.path.trim().isNotEmpty) {
      return Uri(
        path: '/local-workspace',
        queryParameters: <String, String>{
          'path': launchRequest.path.trim(),
          'source': launchRequest.source.trim().isEmpty
              ? 'commandLine'
              : launchRequest.source.trim(),
        },
      ).toString();
    }

    final pendingRequest = _macosOpenService.pendingRequest;
    final path = pendingRequest?.path.trim() ?? '';
    if (path.isEmpty) return '/';
    return Uri(
      path: '/local-workspace',
      queryParameters: <String, String>{
        'path': path,
        'source': pendingRequest?.source.name ?? 'unknown',
      },
    ).toString();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'd1vai Workspace',
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
          routerConfig: _router,
        );
      },
    );
  }
}

class _WorkspaceWindowBootstrap extends StatefulWidget {
  final DesktopWorkspaceLaunchRequest? initialRequest;

  const _WorkspaceWindowBootstrap({this.initialRequest});

  @override
  State<_WorkspaceWindowBootstrap> createState() =>
      _WorkspaceWindowBootstrapState();
}

class _WorkspaceWindowBootstrapState extends State<_WorkspaceWindowBootstrap> {
  bool _opening = false;
  DesktopWorkspaceLaunchRequest? _launchRequest;

  @override
  void initState() {
    super.initState();
    _launchRequest = widget.initialRequest;
  }

  @override
  void didUpdateWidget(covariant _WorkspaceWindowBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.initialRequest, widget.initialRequest)) return;
    _launchRequest = widget.initialRequest;
  }

  void _openPendingRequest() {
    final request = _consumePendingRequest();
    if (request == null || request.path.isEmpty) return;
    setState(() {
      _opening = true;
    });
    GoRouter.of(context).go(
      Uri(
        path: '/local-workspace',
        queryParameters: <String, String>{
          'path': request.path,
          'source': request.source.name,
        },
      ).toString(),
    );
  }

  MacosOpenRequest? _consumePendingRequest() {
    final initialRequest = _launchRequest;
    if (initialRequest != null && initialRequest.path.trim().isNotEmpty) {
      _launchRequest = null;
      return MacosOpenRequest(
        path: initialRequest.path.trim(),
        isDirectory: true,
        openInNewWindow: false,
        source: MacosOpenRequestSource.fromRaw(initialRequest.source),
      );
    }
    return _macosOpenService.consumePendingRequest();
  }

  @override
  Widget build(BuildContext context) {
    final launchRequest = _launchRequest;
    final pendingRequest = context.watch<MacosOpenService>().pendingRequest;
    final shouldOpenPendingRequest =
        !_opening &&
        ((launchRequest != null && launchRequest.path.trim().isNotEmpty) ||
            (pendingRequest != null && pendingRequest.path.trim().isNotEmpty));
    if (shouldOpenPendingRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _opening) return;
        _openPendingRequest();
      });
    }

    if (!_opening) {
      return const DesktopWorkspaceWelcomeScreen();
    }

    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(
              'Opening local workspace...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _launchMacosMenuUri(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> _openLocalWorkspaceFromPicker({
  required bool pickDirectory,
}) async {
  String? selectedPath;

  if (pickDirectory) {
    selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Folder in d1v',
    );
  } else {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      lockParentWindow: true,
      dialogTitle: 'Open File in d1v',
    );
    selectedPath = result?.files.single.path;
  }

  final path = (selectedPath ?? '').trim();
  if (path.isEmpty) return;
  await _openLocalWorkspacePath(
    path,
    source: MacosOpenRequestSource.menu,
    preferNewWindow: true,
  );
}

Future<void> _openLocalWorkspacePath(
  String path, {
  required MacosOpenRequestSource source,
  required bool preferNewWindow,
}) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return;

  if (preferNewWindow && DesktopWindowService.instance.supportsProjectWindows) {
    final opened = await DesktopWindowService.instance.openWorkspaceWindow(
      trimmed,
      source: source,
    );
    if (opened) return;
    await _showLocalWorkspaceOpenFailedDialog(trimmed);
    return;
  }

  final uri = Uri(
    path: '/local-workspace',
    queryParameters: <String, String>{'path': trimmed, 'source': source.name},
  );
  _appRouter.go(uri.toString());
}

Future<void> _showLocalWorkspaceOpenFailedDialog(String path) async {
  final context = _appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Path unavailable'),
        content: Text(
          'd1v could not open this local path. It may have been removed or is no longer readable:\n\n$path',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
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
    final openService = context.watch<MacosOpenService>();
    final pendingRequest = openService.pendingRequest;
    final pendingRoute = openService.pendingRoute;
    final hasPendingRequest =
        pendingRequest != null && pendingRequest.path.isNotEmpty;
    final hasPendingRoute = pendingRoute != null && pendingRoute.isNotEmpty;
    if ((!hasPendingRequest && !hasPendingRoute) || _draining) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draining) return;
      unawaited(_drainPendingEvents());
    });
  }

  Future<void> _drainPendingEvents() async {
    _draining = true;
    try {
      while (mounted) {
        final navigatorContext =
            _appRouter.routerDelegate.navigatorKey.currentContext;
        if (navigatorContext == null) {
          break;
        }
        final pendingRoute = _macosOpenService.pendingRoute;
        if (pendingRoute != null && pendingRoute.isNotEmpty) {
          final route = _macosOpenService.consumePendingRoute();
          if (route != null && route.isNotEmpty) {
            _appRouter.go(route);
            continue;
          }
        }
        final request = _macosOpenService.consumePendingRequest();
        if (request == null || request.path.isEmpty) break;
        await _handleOpenRequest(navigatorContext, request);
      }
    } finally {
      _draining = false;
      if (mounted) {
        final pendingRequest = _macosOpenService.pendingRequest;
        final pendingRoute = _macosOpenService.pendingRoute;
        final hasPendingRequest =
            pendingRequest != null && pendingRequest.path.isNotEmpty;
        final hasPendingRoute = pendingRoute != null && pendingRoute.isNotEmpty;
        if (hasPendingRequest || hasPendingRoute) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _draining) return;
            unawaited(_drainPendingEvents());
          });
        }
      }
    }
  }

  Future<void> _handleOpenRequest(
    BuildContext navigatorContext,
    MacosOpenRequest request,
  ) async {
    final uri = _appRouter.routeInformationProvider.value.uri;
    final currentProjectId = _projectIdFromUri(uri);
    final onLocalWorkspaceRoute = uri.path == '/local-workspace';

    if (request.openInNewWindow ||
        request.source == MacosOpenRequestSource.dock ||
        request.source == MacosOpenRequestSource.openDocument) {
      _openLocalWorkspaceRoute(request);
      return;
    }

    if (onLocalWorkspaceRoute) {
      _openLocalWorkspaceRoute(request);
      return;
    }

    final action = await _showOpenChoiceDialog(
      navigatorContext,
      includeAttach: currentProjectId != null,
    );
    if (!mounted || !navigatorContext.mounted || action == null) return;

    switch (action) {
      case _MacosOpenChoice.attachToCurrentProject:
        final projectId = currentProjectId;
        if (projectId == null || projectId.isEmpty) return;
        final attachUri = Uri(
          path: '/projects/$projectId',
          queryParameters: <String, String>{
            'tab': 'chat',
            'chatTab': 'code',
            'localPath': request.path,
          },
        );
        _appRouter.go(attachUri.toString());
        break;
      case _MacosOpenChoice.openLocally:
        _openLocalWorkspaceRoute(request);
        break;
      case _MacosOpenChoice.importToCloud:
        await _macosFolderImportService.importPath(
          navigatorContext,
          request.path,
        );
        break;
    }
  }

  Future<_MacosOpenChoice?> _showOpenChoiceDialog(
    BuildContext context, {
    required bool includeAttach,
  }) {
    return showDialog<_MacosOpenChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Open Local File or Folder'),
          content: const Text(
            'Choose how d1v should handle the dropped file or folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (includeAttach)
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_MacosOpenChoice.attachToCurrentProject),
                child: const Text('Attach to Project'),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MacosOpenChoice.importToCloud),
              child: const Text('Import to Cloud'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MacosOpenChoice.openLocally),
              child: const Text('Open Locally'),
            ),
          ],
        );
      },
    );
  }

  void _openLocalWorkspaceRoute(MacosOpenRequest request) {
    _appRouter.go(
      Uri(
        path: '/local-workspace',
        queryParameters: <String, String>{
          'path': request.path,
          'source': request.source.name,
        },
      ).toString(),
    );
  }

  String? _projectIdFromUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    if (segments.first != 'projects') return null;
    final projectId = segments[1].trim();
    return projectId.isEmpty ? null : projectId;
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
                'Drop folder or file to open',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Open locally, attach to a project, or import to cloud',
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

enum _MacosOpenChoice { attachToCurrentProject, openLocally, importToCloud }

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
