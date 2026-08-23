import 'dart:async';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/l10n/app_localizations.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/terminal_screen.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/terminal_protocol.dart';
import 'package:d1vai_app/services/terminal_transport.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/terminal/terminal_surface.dart';
import 'package:d1vai_app/widgets/terminal/terminal_mobile_keys.dart';
import 'package:d1vai_app/widgets/terminal/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

class _FakeWorkspace implements WorkspaceReadinessService {
  @override
  Future<WorkspaceConnection> ensureWorkspaceReady({Duration? timeout}) async =>
      const WorkspaceConnection(ip: '10.0.0.1', port: 8080);

  @override
  void setScope({int? organizationId, String? projectId}) {}
}

class _FakeGateway implements ShellSessionGateway {
  int creates = 0;
  int refreshCalls = 0;
  ShellConnection? latestConnection;

  @override
  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    creates += 1;
    final connection = ShellConnection(
      sessionId: 'session-$creates',
      workspaceScope: 'user:7',
      projectId: projectId,
      runtimeProvider: 'fabric',
      nodeId: 'node-1',
      cwd: '/workspace',
      transport: ShellSessionTransport.direct,
      websocketUri: Uri.parse(
        'wss://node.d1v.dev/ws/terminal/session-$creates',
      ),
      connectionTicket: 'secret',
      ticketExpiresAt: DateTime.utc(2026, 8, 24),
    );
    latestConnection = connection;
    return connection;
  }

  @override
  Future<ShellSessionMetadata> close(String sessionId) =>
      SynchronousFuture(_metadata(sessionId));

  @override
  Future<ShellSessionMetadata> get(String sessionId) async =>
      _metadata(sessionId);

  @override
  Future<ShellConnection> refreshTicket(String sessionId) {
    refreshCalls += 1;
    return SynchronousFuture(latestConnection!);
  }

  ShellSessionMetadata _metadata(String sessionId) => ShellSessionMetadata(
    sessionId: sessionId,
    workspaceScope: 'user:7',
    projectId: null,
    cwd: '/workspace',
    status: ShellSessionStatus.terminated,
    exitCode: null,
    terminationReason: 'test',
  );
}

class _FakeTransport implements TerminalTransportClient {
  final outputController = StreamController<Uint8List>.broadcast(sync: true);
  final controlController = StreamController<TerminalServerControl>.broadcast(
    sync: true,
  );
  final failureController =
      StreamController<TerminalTransportFailure>.broadcast(sync: true);
  ShellConnection? connection;
  final List<List<int>> inputs = <List<int>>[];
  bool closed = false;

  @override
  Stream<TerminalServerControl> get controls => controlController.stream;
  @override
  Stream<TerminalTransportFailure> get failures => failureController.stream;
  @override
  bool get isReady => connection != null;
  @override
  Stream<Uint8List> get output => outputController.stream;

  @override
  Future<void> connect(
    ShellConnection connection, {
    required int columns,
    required int rows,
  }) async {
    this.connection = connection;
  }

  @override
  Future<void> close({bool detach = true}) {
    closed = true;
    return SynchronousFuture<void>(null);
  }

  @override
  void resize({required int columns, required int rows}) {}
  @override
  void sendInput(List<int> payload) => inputs.add(List<int>.from(payload));
  @override
  void signal(String signal) {}

  void ready() {
    controlController.add(
      TerminalReady(sessionId: connection!.sessionId, cwd: '/workspace'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preserves split UTF-8 output and follows app theme in place', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    final transport = _FakeTransport();
    final session = TerminalSessionController(
      workspace: _FakeWorkspace(),
      api: gateway,
      transportFactory: () => transport,
    );
    final terminal = Terminal(maxLines: 5000);
    var dark = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return MaterialApp(
            home: Theme(
              data: dark ? ThemeData.dark() : ThemeData.light(),
              child: Scaffold(
                body: TerminalSurface(
                  session: session,
                  targetKey: 'personal:workspace',
                  terminal: terminal,
                ),
              ),
            ),
          );
        },
      ),
    );
    await session.start();
    transport.ready();
    await tester.pump();

    transport.outputController.add(Uint8List.fromList(const [0xE4, 0xB8]));
    transport.outputController.add(Uint8List.fromList(const [0xAD, 0x0A]));
    await tester.pump();

    expect(terminal.buffer.getText(), contains('中'));
    expect(terminal.buffer.getText(), isNot(contains('\uFFFD')));
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme,
      same(d1vTerminalLightTheme),
    );

    setHostState(() => dark = true);
    await tester.pump();

    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).terminal,
      same(terminal),
    );
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme.background,
      d1vTerminalDarkTheme.background,
    );
    expect(gateway.creates, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets('terminal screen toolbar fits a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transports = <_FakeTransport>[];
    final gateway = _FakeGateway();
    final session = TerminalSessionController(
      workspace: _FakeWorkspace(),
      api: gateway,
      transportFactory: () {
        final transport = _FakeTransport();
        transports.add(transport);
        return transport;
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OrganizationProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ],
        child: MaterialApp(
          home: TerminalScreen(controller: session, bootstrapScope: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('terminal-project-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('terminal-project-picker')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('terminal-open-button')).hitTestable(),
      findsOneWidget,
    );
    for (final key in const <String>[
      'terminal-project-picker',
      'terminal-open-button',
    ]) {
      final bounds = tester.getRect(find.byKey(ValueKey(key)));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(390));
    }
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AnimatedPadding>(
            find.byKey(const ValueKey('terminal-safe-insets')),
          )
          .padding,
      const EdgeInsets.only(bottom: 76),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(
      tester
          .widget<AnimatedPadding>(
            find.byKey(const ValueKey('terminal-safe-insets')),
          )
          .padding,
      const EdgeInsets.only(bottom: 300),
    );

    await session.start();
    final transport = transports.single;
    transport.ready();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-key-ctrl')));
    await tester.pump();
    final surface = tester.state<TerminalSurfaceState>(
      find.byType(TerminalSurface),
    );
    surface.terminal.textInput('c');
    surface.terminal.textInput('c');
    expect(transport.inputs.take(2), <List<int>>[
      <int>[3],
      <int>[99],
    ]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 9));
    expect(session.suspended, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(session.suspended, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    session.dispose();
  });

  testWidgets('localizes Arabic chrome while terminal output stays LTR', (
    tester,
  ) async {
    final session = TerminalSessionController(
      workspace: _FakeWorkspace(),
      api: _FakeGateway(),
      transportFactory: _FakeTransport.new,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: TerminalSurface(
            session: session,
            targetKey: 'personal:workspace',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الطرفية مغلقة'), findsOneWidget);
    final directions = tester
        .widgetList<Directionality>(
          find.descendant(
            of: find.byType(TerminalSurface),
            matching: find.byType(Directionality),
          ),
        )
        .map((widget) => widget.textDirection);
    expect(directions, contains(TextDirection.ltr));
    expect(AppLocalizations(const Locale('ja')).translate('terminal'), 'ターミナル');

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets(
    'keeps one live session across responsive locale and theme changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transports = <_FakeTransport>[];
      final gateway = _FakeGateway();
      final session = TerminalSessionController(
        workspace: _FakeWorkspace(),
        api: gateway,
        transportFactory: () {
          final transport = _FakeTransport();
          transports.add(transport);
          return transport;
        },
      );

      Future<void> pumpTerminal({
        required Size size,
        required Brightness brightness,
        required Locale locale,
      }) async {
        tester.view.physicalSize = size;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => OrganizationProvider()),
                ChangeNotifierProvider(create: (_) => ProjectProvider()),
              ],
              child: MaterialApp(
                locale: locale,
                supportedLocales: const <Locale>[
                  Locale('en'),
                  Locale('ja'),
                  Locale('ar'),
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeAnimationDuration: Duration.zero,
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                home: TerminalScreen(
                  controller: session,
                  bootstrapScope: false,
                ),
              ),
            ),
          );
          await tester.pump();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      await pumpTerminal(
        size: const Size(390, 844),
        brightness: Brightness.light,
        locale: const Locale('en'),
      );
      await session.start();
      transports.single.ready();
      await tester.pump();
      final originalTerminal = tester
          .state<TerminalSurfaceState>(find.byType(TerminalSurface))
          .terminal;

      const cases = <({Size size, Brightness brightness, Locale locale})>[
        (
          size: Size(390, 844),
          brightness: Brightness.light,
          locale: Locale('en'),
        ),
        (
          size: Size(390, 844),
          brightness: Brightness.dark,
          locale: Locale('ar'),
        ),
        (
          size: Size(768, 1024),
          brightness: Brightness.light,
          locale: Locale('ar'),
        ),
        (
          size: Size(768, 1024),
          brightness: Brightness.dark,
          locale: Locale('ja'),
        ),
        (
          size: Size(1440, 900),
          brightness: Brightness.light,
          locale: Locale('ja'),
        ),
        (
          size: Size(1440, 900),
          brightness: Brightness.dark,
          locale: Locale('ar'),
        ),
      ];

      for (final testCase in cases) {
        await pumpTerminal(
          size: testCase.size,
          brightness: testCase.brightness,
          locale: testCase.locale,
        );

        final surface = tester.state<TerminalSurfaceState>(
          find.byType(TerminalSurface),
        );
        expect(surface.terminal, same(originalTerminal));
        expect(gateway.creates, 1);
        expect(transports, hasLength(1));
        expect(
          tester.widget<TerminalView>(find.byType(TerminalView)).theme,
          isA<TerminalTheme>().having(
            (theme) => theme.background,
            'background',
            testCase.brightness == Brightness.dark
                ? d1vTerminalDarkTheme.background
                : d1vTerminalLightTheme.background,
          ),
        );
        expect(
          find.byType(TerminalMobileKeys),
          testCase.size.width < 880 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets('matches representative responsive terminal goldens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const cases =
        <({String name, Size size, Brightness brightness, Locale locale})>[
          (
            name: 'phone_light_en',
            size: Size(390, 844),
            brightness: Brightness.light,
            locale: Locale('en'),
          ),
          (
            name: 'tablet_dark_ja',
            size: Size(768, 1024),
            brightness: Brightness.dark,
            locale: Locale('ja'),
          ),
          (
            name: 'desktop_light_ar',
            size: Size(1440, 900),
            brightness: Brightness.light,
            locale: Locale('ar'),
          ),
        ];

    for (final testCase in cases) {
      final session = TerminalSessionController(
        workspace: _FakeWorkspace(),
        api: _FakeGateway(),
        transportFactory: _FakeTransport.new,
      );
      tester.view.physicalSize = testCase.size;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => OrganizationProvider()),
              ChangeNotifierProvider(create: (_) => ProjectProvider()),
            ],
            child: MaterialApp(
              locale: testCase.locale,
              supportedLocales: const <Locale>[
                Locale('en'),
                Locale('ja'),
                Locale('ar'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeAnimationDuration: Duration.zero,
              themeMode: testCase.brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: RepaintBoundary(
                child: TerminalScreen(
                  controller: session,
                  bootstrapScope: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/terminal_${testCase.name}.png'),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    }
  });
}
