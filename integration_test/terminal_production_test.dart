import 'dart:convert';

import 'package:d1vai_app/controllers/terminal_session_controller.dart';
import 'package:d1vai_app/core/api_client.dart';
import 'package:d1vai_app/models/shell_session.dart';
import 'package:d1vai_app/providers/organization_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/screens/terminal_screen.dart';
import 'package:d1vai_app/services/shell_session_api.dart';
import 'package:d1vai_app/services/workspace_service.dart';
import 'package:d1vai_app/widgets/terminal/terminal_surface.dart';
import 'package:d1vai_app/widgets/terminal/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';

const _primaryToken = String.fromEnvironment('D1V_E2E_AUTH_TOKEN');
const _secondaryToken = String.fromEnvironment('D1V_E2E_SECONDARY_AUTH_TOKEN');
const _projectId = String.fromEnvironment('D1V_E2E_PROJECT_ID');
const _organizationIdValue = String.fromEnvironment('D1V_E2E_ORGANIZATION_ID');
const _apiBaseUrl = String.fromEnvironment(
  'D1V_E2E_API_BASE_URL',
  defaultValue: 'https://api.d1v.ai',
);
final int? _organizationId = int.tryParse(_organizationIdValue);
final bool _hasPrimary =
    _primaryToken.trim().isNotEmpty && _projectId.trim().isNotEmpty;
final bool _hasFullMatrix =
    _hasPrimary && _secondaryToken.trim().isNotEmpty && _organizationId != null;

class _RecordingGateway implements ShellSessionGateway {
  final ShellSessionGateway _delegate;
  final List<ShellConnection> connections = <ShellConnection>[];
  final List<String> closedSessionIds = <String>[];

  _RecordingGateway({ShellSessionGateway? delegate})
    : _delegate = delegate ?? ShellSessionApi();

  @override
  Future<ShellConnection> create({
    String? projectId,
    int? organizationId,
    required int columns,
    required int rows,
  }) async {
    final connection = await _delegate.create(
      projectId: projectId,
      organizationId: organizationId,
      columns: columns,
      rows: rows,
    );
    connections.add(connection);
    return connection;
  }

  @override
  Future<ShellSessionMetadata> get(String sessionId) =>
      _delegate.get(sessionId);

  @override
  Future<ShellConnection> refreshTicket(String sessionId) =>
      _delegate.refreshTicket(sessionId);

  @override
  Future<ShellSessionMetadata> close(String sessionId) async {
    final result = await _delegate.close(sessionId);
    closedSessionIds.add(sessionId);
    return result;
  }
}

class _ProductionTerminalHarness {
  final WidgetTester tester;
  final String projectId;
  final _RecordingGateway gateway = _RecordingGateway();
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );
  late final TerminalSessionController session = TerminalSessionController(
    workspace: WorkspaceService(),
    api: gateway,
  );
  bool _disposed = false;

  _ProductionTerminalHarness(this.tester, {required this.projectId});

  Future<void> mount() async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OrganizationProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeAnimationDuration: Duration.zero,
            themeMode: mode,
            home: TerminalScreen(
              initialProjectId: projectId,
              controller: session,
              bootstrapScope: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openFromUi() async {
    await tester.tap(
      find.byKey(const ValueKey('terminal-open-button')).hitTestable(),
    );
    await tester.pump();
    await waitUntilReady();
  }

  Future<void> openOrganization(int organizationId) async {
    await session.start(
      projectId: projectId,
      organizationId: organizationId,
      columns: session.columns,
      rows: session.rows,
    );
    await waitUntilReady();
  }

  Future<void> waitUntilReady() async {
    await _pumpUntil(
      tester,
      () {
        if (session.phase == TerminalSessionPhase.error ||
            session.phase == TerminalSessionPhase.denied ||
            session.phase == TerminalSessionPhase.capacity ||
            session.phase == TerminalSessionPhase.exited) {
          throw TestFailure(
            'Terminal failed before ready: '
            '${session.phase.name}/${session.errorCode ?? 'no_code'}',
          );
        }
        return session.phase == TerminalSessionPhase.ready;
      },
      timeout: const Duration(minutes: 4),
      description: 'terminal ready state',
    );
  }

  TerminalSurfaceState get surface =>
      tester.state<TerminalSurfaceState>(find.byType(TerminalSurface));

  String get text => surface.terminal.buffer.getText();

  Future<void> closeFromUi() async {
    await tester.tap(
      find.byKey(const ValueKey('terminal-close-button')).hitTestable(),
    );
    await _pumpUntil(
      tester,
      () => session.phase == TerminalSessionPhase.idle,
      description: 'terminal close',
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await session.shutdown();
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    themeMode.dispose();
  }
}

Future<void> _configureIdentity(String token, {int? organizationId}) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('auth_token', token.trim());
  if (organizationId == null) {
    await preferences.remove('active_organization_id');
  } else {
    await preferences.setInt('active_organization_id', organizationId);
  }
  await ApiClient.setRuntimeBaseUrlOverride(_apiBaseUrl);
}

Future<void> _clearIdentity() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove('auth_token');
  await preferences.remove('active_organization_id');
  await ApiClient.setRuntimeBaseUrlOverride(null);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  required String description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out waiting for $description');
}

Future<void> _waitForText(
  _ProductionTerminalHarness harness,
  bool Function(String text) condition, {
  Duration timeout = const Duration(seconds: 20),
  String description = 'terminal output',
}) => _pumpUntil(
  harness.tester,
  () => condition(harness.text),
  timeout: timeout,
  description: description,
);

String _octalUtf8(String value) => utf8
    .encode(value)
    .map((byte) => '\\${byte.toRadixString(8).padLeft(3, '0')}')
    .join();

void _typeCommand(TerminalSurfaceState surface, String command) {
  surface.terminal.textInput(command);
  surface.sendKey(TerminalKey.enter);
}

int _occurrences(String value, String needle) {
  if (needle.isEmpty) return 0;
  return value.split(needle).length - 1;
}

bool _markerUsesNamedForeground(
  Terminal terminal,
  String marker,
  int colorIndex,
) {
  final expectedForeground = CellColor.named | colorIndex;
  final lines = terminal.buffer.lines;
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final line = lines[lineIndex];
    final start = line.getText().indexOf(marker);
    if (start < 0 || start + marker.length > line.length) continue;
    for (var offset = 0; offset < marker.length; offset += 1) {
      if (line.getForeground(start + offset) != expectedForeground) {
        return false;
      }
    }
    return true;
  }
  return false;
}

Future<void> _emitMarker(
  _ProductionTerminalHarness harness,
  String marker,
) async {
  _typeCommand(harness.surface, " printf '${_octalUtf8(marker)}\\n'");
  await _waitForText(
    harness,
    (text) => text.contains(marker),
    description: 'encoded command result',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'runs the real Flutter production project terminal journey',
    (tester) async {
      final apiUri = Uri.parse(_apiBaseUrl);
      expect(apiUri.scheme, 'https');
      await _configureIdentity(_primaryToken);
      addTearDown(_clearIdentity);

      final harness = _ProductionTerminalHarness(
        tester,
        projectId: _projectId.trim(),
      );
      addTearDown(harness.dispose);
      await harness.mount();
      await harness.openFromUi();

      expect(harness.gateway.connections, hasLength(1));
      final firstConnection = harness.gateway.connections.single;
      expect(firstConnection.websocketUri.scheme, 'wss');
      expect(firstConnection.projectId, _projectId.trim());
      expect(harness.session.cwd, firstConnection.cwd);

      _typeCommand(harness.surface, ' pwd');
      await _waitForText(
        harness,
        (text) => text.contains(firstConnection.cwd),
        description: 'server-resolved project directory',
      );

      final runId = DateTime.now().microsecondsSinceEpoch.toString();
      final unicodeMarker = 'D1V_FLUTTER_中文_$runId';
      await _emitMarker(harness, unicodeMarker);

      final ansiMarker = 'D1V_FLUTTER_ANSI_$runId';
      _typeCommand(
        harness.surface,
        " printf '\\033[31m${_octalUtf8(ansiMarker)}\\033[0m\\n'",
      );
      await _waitForText(
        harness,
        (text) => text.contains(ansiMarker),
        description: 'ANSI command result',
      );
      expect(
        _markerUsesNamedForeground(harness.surface.terminal, ansiMarker, 1),
        isTrue,
      );

      final semanticMarker = 'D1V_FLUTTER_SEMANTIC_$runId';
      _typeCommand(
        harness.surface,
        " printf '${_octalUtf8('warning $semanticMarker')}\\n'",
      );
      await _waitForText(
        harness,
        (text) => text.contains(semanticMarker),
        description: 'semantic command result',
      );
      expect(
        _markerUsesNamedForeground(harness.surface.terminal, semanticMarker, 3),
        isTrue,
      );

      final completionName = 'd1v-flutter-$runId-completion.txt';
      final completionReady = 'D1V_FLUTTER_COMPLETION_READY_$runId';
      _typeCommand(
        harness.surface,
        " completion=\$(printf '${_octalUtf8(completionName)}'); "
        ': > "/tmp/\$completion"; '
        "printf '${_octalUtf8(completionReady)}\\n'",
      );
      await _waitForText(
        harness,
        (text) => text.contains(completionReady),
        description: 'completion fixture',
      );
      final completionPrefix = completionName.substring(
        0,
        completionName.length - 8,
      );
      harness.surface.terminal.textInput('cat /tmp/$completionPrefix');
      harness.surface.sendKey(TerminalKey.tab);
      await _waitForText(
        harness,
        (text) => text.contains(completionName),
        description: 'Tab completion',
      );
      harness.surface.terminal.textInput('\x03');
      _typeCommand(harness.surface, ' rm -f /tmp/$completionName');
      final afterInterrupt = 'D1V_FLUTTER_AFTER_INTERRUPT_$runId';
      await _emitMarker(harness, afterInterrupt);

      final originalTerminal = harness.surface.terminal;
      harness.themeMode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(harness.surface.terminal, same(originalTerminal));
      expect(
        tester.widget<TerminalView>(find.byType(TerminalView)).theme.background,
        d1vTerminalDarkTheme.background,
      );
      expect(harness.gateway.connections, hasLength(1));
      harness.session.updateSize(92, 31);
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.gateway.connections, hasLength(1));

      final boundaryDone = 'D1V_FLUTTER_BOUNDARY_DONE_$runId';
      _typeCommand(
        harness.surface,
        " printf '${_octalUtf8('D1V_UID=')}'; id -u; "
        "sed -n '/^CapEff:/p;/^CapBnd:/p;/^NoNewPrivs:/p;/^Seccomp:/p' "
        '/proc/self/status; '
        "printf '${_octalUtf8('D1V_PIDS=')}'; "
        '(cat /sys/fs/cgroup/pids.max 2>/dev/null || '
        'cat /sys/fs/cgroup/pids/pids.max); '
        'test ! -S /var/run/docker.sock && '
        "printf '${_octalUtf8('D1V_NO_DOCKER_SOCKET\n')}'; "
        'test ! -e /host && '
        "printf '${_octalUtf8('D1V_NO_HOST_MOUNT\n')}'; "
        "printf '${_octalUtf8('$boundaryDone\n')}'",
      );
      await _waitForText(
        harness,
        (text) => text.contains(boundaryDone),
        description: 'container boundary probe',
      );
      expect(harness.text, contains('D1V_UID=1000'));
      expect(harness.text, contains(RegExp(r'CapEff:\s+0+')));
      expect(harness.text, contains(RegExp(r'CapBnd:\s+0+')));
      expect(harness.text, contains(RegExp(r'NoNewPrivs:\s+1')));
      expect(harness.text, contains(RegExp(r'Seccomp:\s+2')));
      expect(harness.text, contains('D1V_PIDS=512'));
      expect(harness.text, contains('D1V_NO_DOCKER_SOCKET'));
      expect(harness.text, contains('D1V_NO_HOST_MOUNT'));

      final historySuffix = runId.substring(runId.length - 6);
      final rightCommand = 'echo D1V_FLUTTER_RIGHT_$historySuffix';
      final endCommand = 'echo D1V_FLUTTER_END_$historySuffix';
      final reverseCommand = 'echo D1V_FLUTTER_CTRL_R_$historySuffix';
      for (final command in [rightCommand, endCommand, reverseCommand]) {
        _typeCommand(harness.surface, command);
        await _waitForText(
          harness,
          (text) => _occurrences(text, command) >= 2,
          description: 'history seed command',
        );
      }
      await _emitMarker(harness, 'D1V_FLUTTER_HISTORY_SYNC_$runId');

      await harness.closeFromUi();
      expect(harness.gateway.closedSessionIds, isNotEmpty);
      await harness.openFromUi();
      expect(harness.gateway.connections, hasLength(2));

      final rightPrefix = rightCommand.substring(0, rightCommand.length - 3);
      harness.surface.terminal.textInput(rightPrefix);
      await _waitForText(
        harness,
        (text) => text.contains(rightCommand),
        description: 'Right Arrow history suggestion',
      );
      harness.surface.sendKey(TerminalKey.arrowRight);
      harness.surface.sendKey(TerminalKey.enter);
      await _waitForText(
        harness,
        (text) => _occurrences(text, rightCommand) >= 2,
        description: 'Right Arrow suggestion acceptance',
      );

      final endPrefix = endCommand.substring(0, endCommand.length - 3);
      harness.surface.terminal.textInput(endPrefix);
      await _waitForText(
        harness,
        (text) => text.contains(endCommand),
        description: 'End history suggestion',
      );
      harness.surface.sendKey(TerminalKey.end);
      harness.surface.sendKey(TerminalKey.enter);
      await _waitForText(
        harness,
        (text) => _occurrences(text, endCommand) >= 2,
        description: 'End suggestion acceptance',
      );

      harness.surface.terminal.textInput('\x12');
      harness.surface.terminal.textInput('D1V_FLUTTER_CTRL_R_');
      await _waitForText(
        harness,
        (text) => text.contains(reverseCommand),
        description: 'Ctrl-R history search',
      );
      harness.surface.sendKey(TerminalKey.enter);
      await _waitForText(
        harness,
        (text) => _occurrences(text, reverseCommand) >= 2,
        description: 'Ctrl-R command execution',
      );

      _typeCommand(
        harness.surface,
        " for n in \$(history | awk '/D1V_FLUTTER_(RIGHT|END|CTRL_R)_/ "
        "{print \$1}' | sort -rn); do history -d \"\$n\"; done; history -w",
      );
      await _emitMarker(harness, 'D1V_FLUTTER_PRIMARY_DONE_$runId');
      expect(tester.takeException(), isNull);
    },
    skip: !_hasPrimary,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'keeps organization history private across production identities',
    (tester) async {
      final organizationId = _organizationId!;
      final runId = DateTime.now().microsecondsSinceEpoch.toString();
      final privateCommand =
          'echo D1V_FLUTTER_PRIVATE_${runId.substring(runId.length - 8)}';

      await _configureIdentity(_primaryToken, organizationId: organizationId);
      addTearDown(_clearIdentity);
      final primary = _ProductionTerminalHarness(
        tester,
        projectId: _projectId.trim(),
      );
      addTearDown(primary.dispose);
      await primary.mount();
      await primary.openOrganization(organizationId);
      expect(
        primary.gateway.connections.single.workspaceScope,
        'organization:$organizationId',
      );
      _typeCommand(primary.surface, privateCommand);
      await _waitForText(
        primary,
        (text) => _occurrences(text, privateCommand) >= 2,
        description: 'primary private history seed',
      );
      await _emitMarker(primary, 'D1V_FLUTTER_PRIVATE_SYNC_$runId');
      await primary.dispose();
      expect(primary.gateway.closedSessionIds, hasLength(1));

      await _configureIdentity(_secondaryToken, organizationId: organizationId);
      final secondary = _ProductionTerminalHarness(
        tester,
        projectId: _projectId.trim(),
      );
      addTearDown(secondary.dispose);
      await secondary.mount();
      await secondary.openOrganization(organizationId);
      expect(
        secondary.gateway.connections.single.workspaceScope,
        'organization:$organizationId',
      );
      final prefix = privateCommand.substring(0, privateCommand.length - 4);
      secondary.surface.terminal.textInput(prefix);
      await tester.pump(const Duration(seconds: 3));
      expect(secondary.text, isNot(contains(privateCommand)));
      secondary.surface.terminal.textInput('\x03');

      secondary.surface.terminal.textInput('\x12');
      secondary.surface.terminal.textInput('D1V_FLUTTER_PRIVATE_');
      await tester.pump(const Duration(seconds: 3));
      expect(secondary.text, isNot(contains(privateCommand)));
      secondary.surface.terminal.textInput('\x03');

      await _emitMarker(secondary, 'D1V_FLUTTER_SECONDARY_DONE_$runId');
      await secondary.dispose();
      expect(secondary.gateway.closedSessionIds, hasLength(1));

      await _configureIdentity(_primaryToken, organizationId: organizationId);
      final cleanup = _ProductionTerminalHarness(
        tester,
        projectId: _projectId.trim(),
      );
      addTearDown(cleanup.dispose);
      await cleanup.mount();
      await cleanup.openOrganization(organizationId);
      _typeCommand(
        cleanup.surface,
        " for n in \$(history | awk '/D1V_FLUTTER_PRIVATE_/ {print \$1}' "
        "| sort -rn); do history -d \"\$n\"; done; history -w",
      );
      await _emitMarker(cleanup, 'D1V_FLUTTER_PRIVATE_CLEAN_$runId');
      await cleanup.dispose();
      expect(cleanup.gateway.closedSessionIds, hasLength(1));
      expect(tester.takeException(), isNull);
    },
    skip: !_hasFullMatrix,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
