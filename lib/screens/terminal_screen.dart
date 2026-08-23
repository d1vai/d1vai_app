import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/terminal_session_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../providers/organization_provider.dart';
import '../providers/project_provider.dart';
import '../services/shell_session_api.dart';
import '../services/workspace_service.dart';
import '../utils/desktop_layout.dart';
import '../widgets/organization/workspace_switcher.dart';
import '../widgets/terminal/terminal_project_picker.dart';
import '../widgets/terminal/terminal_mobile_keys.dart';
import '../widgets/terminal/terminal_surface.dart';

class TerminalScreen extends StatefulWidget {
  final String? initialProjectId;
  final TerminalSessionController? controller;
  final bool bootstrapScope;

  const TerminalScreen({
    super.key,
    this.initialProjectId,
    this.controller,
    this.bootstrapScope = true,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  late final TerminalSessionController _session;
  late final bool _ownsSession;
  final GlobalKey<TerminalSurfaceState> _surfaceKey = GlobalKey();
  String? _selectedProjectId;
  int? _organizationId;
  bool _scopeObserved = false;
  bool _scopeLoading = true;
  bool _scopeChangeScheduled = false;
  bool _oneShotCtrl = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsSession = widget.controller == null;
    _session =
        widget.controller ??
        TerminalSessionController(
          workspace: WorkspaceService(),
          api: ShellSessionApi(),
        );
    _selectedProjectId = _normalizeProjectId(widget.initialProjectId);
    _session.addListener(_onSessionChanged);
    if (widget.bootstrapScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_bootstrap());
      });
    } else {
      _scopeLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.bootstrapScope) return;
    final organizationId = context
        .watch<OrganizationProvider>()
        .activeOrganizationId;
    if (_scopeObserved && organizationId != _organizationId) {
      _scheduleOrganizationChange(organizationId);
    }
  }

  Future<void> _bootstrap() async {
    final organizations = context.read<OrganizationProvider>();
    final projects = context.read<ProjectProvider>();
    await organizations.load();
    if (!mounted) return;
    _organizationId = organizations.activeOrganizationId;
    _scopeObserved = true;
    await projects.setOrganization(_organizationId);
    if (!mounted) return;
    if (_selectedProjectId != null &&
        projects.getProjectById(_selectedProjectId!) == null) {
      _selectedProjectId = null;
    }
    setState(() => _scopeLoading = false);
  }

  void _scheduleOrganizationChange(int? organizationId) {
    if (_scopeChangeScheduled) return;
    _scopeChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scopeChangeScheduled = false;
      if (mounted && organizationId != _organizationId) {
        unawaited(_changeOrganization(organizationId));
      }
    });
  }

  Future<void> _changeOrganization(int? organizationId) async {
    final projects = context.read<ProjectProvider>();
    final restart = _hasLiveSession;
    setState(() {
      _scopeLoading = true;
      _organizationId = organizationId;
      _selectedProjectId = null;
      _oneShotCtrl = false;
    });
    await _session.shutdown();
    _surfaceKey.currentState?.clear();
    await projects.setOrganization(organizationId);
    if (!mounted) return;
    setState(() => _scopeLoading = false);
    if (restart) await _start();
  }

  bool get _hasLiveSession => switch (_session.phase) {
    TerminalSessionPhase.checking ||
    TerminalSessionPhase.waking ||
    TerminalSessionPhase.creating ||
    TerminalSessionPhase.connecting ||
    TerminalSessionPhase.ready ||
    TerminalSessionPhase.reconnecting => true,
    _ => false,
  };

  Future<void> _selectProject(String? projectId) async {
    final normalized = _normalizeProjectId(projectId);
    if (normalized == _selectedProjectId) return;
    final restart = _hasLiveSession;
    setState(() {
      _selectedProjectId = normalized;
      _oneShotCtrl = false;
    });
    if (restart) await _start();
  }

  Future<void> _start() async {
    _surfaceKey.currentState?.clear();
    await _session.start(
      projectId: _selectedProjectId,
      organizationId: _organizationId,
      columns: _session.columns,
      rows: _session.rows,
    );
  }

  Future<void> _close() async {
    if (_oneShotCtrl) setState(() => _oneShotCtrl = false);
    await _session.shutdown();
    _surfaceKey.currentState?.clear();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    if (_session.phase == TerminalSessionPhase.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _surfaceKey.currentState?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>();
    final desktop = isDesktopLayout(context);
    final view = View.of(context);
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    const mobileNavigationClearance = 76.0;
    final bottomClearance = desktop
        ? 0.0
        : keyboardInset > 0
        ? keyboardInset
        : mobileNavigationClearance;
    final targetKey =
        '${_organizationId ?? 'personal'}:'
        '${_selectedProjectId ?? 'workspace'}';
    final toolbar = _TerminalToolbar(
      scopeLoading: _scopeLoading || projects.isLoading,
      projects: projects.projects,
      selectedProjectId: _selectedProjectId,
      session: _session,
      onProjectSelected: _selectProject,
      onOpen: _start,
      onClose: _close,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: AnimatedPadding(
        key: const ValueKey('terminal-safe-insets'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomClearance),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(desktop ? 20 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(desktop ? 8 : 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    toolbar,
                    Expanded(
                      child: TerminalSurface(
                        key: _surfaceKey,
                        session: _session,
                        targetKey: targetKey,
                        onOpen: _scopeLoading ? null : _start,
                        onRetry: _scopeLoading ? null : _start,
                        oneShotCtrl: _oneShotCtrl,
                        onOneShotCtrlConsumed: () {
                          if (mounted && _oneShotCtrl) {
                            setState(() => _oneShotCtrl = false);
                          }
                        },
                      ),
                    ),
                    if (!desktop)
                      TerminalMobileKeys(
                        enabled: _session.acceptsInput,
                        ctrlArmed: _oneShotCtrl,
                        onCtrlToggle: () {
                          setState(() => _oneShotCtrl = !_oneShotCtrl);
                          _surfaceKey.currentState?.requestFocus();
                        },
                        onKey: (key) => _surfaceKey.currentState?.sendKey(key),
                        onCopy: () {
                          final surface = _surfaceKey.currentState;
                          if (surface != null) {
                            unawaited(surface.copySelection());
                          }
                        },
                        onPaste: () {
                          final surface = _surfaceKey.currentState;
                          if (surface != null) {
                            unawaited(surface.pasteClipboard());
                          }
                        },
                        onHideKeyboard: () {
                          _surfaceKey.currentState?.hideKeyboard();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalToolbar extends StatelessWidget {
  final bool scopeLoading;
  final List<UserProject> projects;
  final String? selectedProjectId;
  final TerminalSessionController session;
  final ValueChanged<String?> onProjectSelected;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _TerminalToolbar({
    required this.scopeLoading,
    required this.projects,
    required this.selectedProjectId,
    required this.session,
    required this.onProjectSelected,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = switch (session.phase) {
      TerminalSessionPhase.checking ||
      TerminalSessionPhase.waking ||
      TerminalSessionPhase.creating ||
      TerminalSessionPhase.connecting ||
      TerminalSessionPhase.ready ||
      TerminalSessionPhase.reconnecting => true,
      _ => false,
    };
    return Material(
      color: scheme.surface,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final workspace = SizedBox(
              width: compact ? 178 : 220,
              child: const WorkspaceSwitcher(),
            );
            final project = TerminalProjectPicker(
              projects: projects,
              selectedProjectId: selectedProjectId,
              enabled: !scopeLoading,
              onSelected: onProjectSelected,
            );
            final trailing = <Widget>[
              _TerminalStatusChip(session: session),
              const SizedBox(width: 4),
              IconButton(
                key: ValueKey(
                  running ? 'terminal-close-button' : 'terminal-open-button',
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                tooltip: running
                    ? context.tr('terminal_action_close', 'Close terminal')
                    : context.tr('terminal_action_open', 'Open terminal'),
                onPressed: scopeLoading
                    ? null
                    : running
                    ? onClose
                    : onOpen,
                icon: Icon(
                  running ? Icons.close_rounded : Icons.play_arrow_rounded,
                ),
              ),
            ];
            if (!compact) {
              return Row(
                children: [
                  workspace,
                  const SizedBox(width: 8),
                  Expanded(child: project),
                  const SizedBox(width: 8),
                  ...trailing,
                ],
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  workspace,
                  const SizedBox(width: 8),
                  SizedBox(width: 220, child: project),
                  const SizedBox(width: 8),
                  ...trailing,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TerminalStatusChip extends StatelessWidget {
  final TerminalSessionController session;

  const _TerminalStatusChip({required this.session});

  @override
  Widget build(BuildContext context) {
    final ready = session.phase == TerminalSessionPhase.ready;
    final pending = switch (session.phase) {
      TerminalSessionPhase.checking ||
      TerminalSessionPhase.waking ||
      TerminalSessionPhase.creating ||
      TerminalSessionPhase.connecting ||
      TerminalSessionPhase.reconnecting => true,
      _ => false,
    };
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: session.cwd ?? _phaseLabel(context, session.phase),
      child: Semantics(
        liveRegion: true,
        label: _phaseLabel(context, session.phase),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: ready
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  ready ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: ready ? scheme.primary : scheme.onSurfaceVariant,
                ),
              if (!pending && ready) ...[
                const SizedBox(width: 6),
                Text(
                  context.tr('terminal_status_ready', 'Ready'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _phaseLabel(BuildContext context, TerminalSessionPhase phase) =>
      switch (phase) {
        TerminalSessionPhase.idle => context.tr(
          'terminal_status_idle',
          'Terminal is closed',
        ),
        TerminalSessionPhase.checking => context.tr(
          'terminal_status_checking',
          'Checking workspace',
        ),
        TerminalSessionPhase.waking => context.tr(
          'terminal_status_waking',
          'Starting workspace',
        ),
        TerminalSessionPhase.creating => context.tr(
          'terminal_status_creating',
          'Creating terminal session',
        ),
        TerminalSessionPhase.connecting => context.tr(
          'terminal_status_connecting',
          'Connecting',
        ),
        TerminalSessionPhase.ready => context.tr(
          'terminal_status_ready',
          'Ready',
        ),
        TerminalSessionPhase.reconnecting => context.tr(
          'terminal_status_reconnecting',
          'Reconnecting',
        ),
        TerminalSessionPhase.exited => context.tr(
          'terminal_status_exited',
          'Process exited',
        ),
        TerminalSessionPhase.denied => context.tr(
          'terminal_status_denied',
          'Terminal access denied',
        ),
        TerminalSessionPhase.capacity => context.tr(
          'terminal_status_capacity',
          'Terminal session limit reached',
        ),
        TerminalSessionPhase.error => context.tr(
          'terminal_status_error',
          'Terminal connection failed',
        ),
      };
}

String? _normalizeProjectId(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
