part of '../../project_chat/project_chat_tab.dart';

enum WsConnectionState { idle, connecting, connected, failed }

abstract class _ProjectChatTabStateBase extends State<ProjectChatTab>
    with AutomaticKeepAliveClientMixin {
  final ChatService _chatService = ChatService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final ModelConfigService _modelConfigService = ModelConfigService();
  final StorageService _storageService = StorageService();
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();
  final FocusNode _chatInputFocusNode = FocusNode();
  final Map<String, MessageStatus> _messageStatuses = {};
  final D1vaiService _d1vaiService = D1vaiService();
  final CodeTabTopBarController _codeTabTopBarController =
      CodeTabTopBarController();

  bool _isChatLoading = false;
  bool _isLoadingHistory = false;
  String? _currentSessionId;
  String? _lastSessionModelId;
  String? _lastSessionEngine;
  bool _historyLoaded = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  DateTime? _oldestMessageAt;

  // Session UI phase (align with web's mobileStatusLabel)
  bool _sessionThinking = false;
  bool _sessionDone = false;
  bool _sessionError = false;
  Timer? _thinkingClearTimer;
  DateTime? _lastSessionFinishedAt;
  Timer? _chatDraftPersistTimer;
  String _lastPersistedChatDraft = '';
  Timer? _scrollToBottomTimer;
  DateTime? _lastScrollToBottomAt;

  // Workspace state (align with web BigChat)
  WorkspaceStateInfo? _workspaceState;
  WorkspacePhase _workspacePhase = WorkspacePhase.unknown;
  String? _workspaceError;
  Timer? _workspacePollTimer;
  bool _workspacePollInFlight = false;
  bool _workspaceWarmupInFlight = false;
  int _workspacePollErrorStreak = 0;
  bool _workspaceWarmupVisible = false;
  bool _workspaceWarmupCompleted = false;
  String? _workspaceWarmupMessage;

  // Model selection state (align with web BigChat/create flow)
  List<ModelInfo> _availableModels = <ModelInfo>[];
  String _selectedModelId = '';
  ChatEngineMode _selectedEngineMode = ChatEngineMode.thinkHard;
  bool _isLoadingModels = false;
  bool _isSwitchingModel = false;
  bool _hasLoadedModelConfig = false;
  String? _modelConfigError;
  Timer? _modelConfigRetryTimer;

  // WebSocket runtime (similar responsibilities to web's wsManager + useWebSocket)
  String? _activeWsSessionId;
  String? _activeWsUrlOverride;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualWsClose = false;
  bool _autoConnectDisabled = false;
  final Set<String> _seenWsKeys = <String>{};
  final Map<String, int> _recentEventFingerprints = <String, int>{};
  final List<_PendingAppendItem> _pendingAppendQueue = <_PendingAppendItem>[];
  final Set<String> _pendingAppendWsKeys = <String>{};
  Timer? _pendingAppendTimer;
  Timer? _terminalCloseTimer;
  WsConnectionState _wsConnState = WsConnectionState.idle;
  String? _currentWsTurnId;
  bool _wsSessionTerminated = false;

  // Mobile chat bottom sheet state
  bool _showMobileChat = false;
  double _mobileChatSheetExtent = 0.7;
  int _mobileChatSheetStage = 1;

  // Outbox queue (mobile-friendly message queue)
  final List<OutboxItem> _outboxItems = <OutboxItem>[];
  OutboxMode _outboxMode = OutboxMode.idle;
  bool _outboxDrainInFlight = false;
  int _outboxAbortToken = 0;
  final StreamController<void> _outboxSignals =
      StreamController<void>.broadcast(sync: true);

  // Sub-tab state (Preview / Code)
  int _currentChatTabIndex = 0;

  // Desktop split-pane state
  double _desktopChatPaneWidth = 392;
  bool _desktopChatPaneCollapsed = false;
  final double _desktopChatPaneDefaultWidth = 392;
  final double _desktopChatPaneMinWidth = 312;
  final double _desktopChatPaneMaxWidth = 540;
  final double _desktopChatPaneCollapsedWidth = 54;
  final double _desktopPrimaryPaneMinWidth = 420;
  ProjectFileLinkRequest? _pendingProjectFileRequest;
  int _projectFileRequestRevision = 0;

  int _chatSubTabIndexFromName(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      final preview = (widget.previewUrl ?? '').trim();
      return preview.isNotEmpty ? 0 : 1;
    }
    switch (normalized) {
      case 'code':
      case 'files':
      case 'file':
        return 1;
      case 'preview':
      default:
        return 0;
    }
  }

  // Preview runtime
  String? _previewUrl;
  int _previewKey = 0;
  String? _lastTrackedPreviewKey;

  // Deployment runtime (for preview redeploy + WS deployment frames)
  bool _isDeploying = false;
  String? _deployFramework;
  Timer? _deployAutoClearTimer;
  Timer? _deployStatusPollTimer;
  int _deployStatusPollRun = 0;
  DateTime? _lastDeployCompletedAt;

  // UI notice cooldowns to avoid snackbar/error storms.
  final Map<String, DateTime> _noticeCooldowns = <String, DateTime>{};

  @override
  bool get wantKeepAlive => true;

  /// 允许其他 Tab 触发首条消息并自动切换到 Preview 子标签
  void sendInitialPrompt(String text) {
    _currentChatTabIndex = 0;
    _trackPreviewOpenedIfNeeded();
    _sendFirstMessage(text);
  }

  void _trackPreviewOpenedIfNeeded() {
    final preview = (_previewUrl ?? '').trim();
    if (_currentChatTabIndex != 0 || preview.isEmpty) return;
    final key = '${widget.projectId}:$preview';
    if (_lastTrackedPreviewKey == key) return;
    _lastTrackedPreviewKey = key;
    unawaited(
      AppAnalyticsService.instance.trackPreviewOpened(
        projectId: widget.projectId,
        previewUrl: preview,
      ),
    );
  }

  void _trackTabSelection() {
    final hasPreview = (_previewUrl ?? '').trim().isNotEmpty;
    final tab = _currentChatTabIndex == 0 ? 'preview' : 'code';
    unawaited(
      AppAnalyticsService.instance.trackChatTabSwitched(
        projectId: widget.projectId,
        tab: tab,
        hasPreview: hasPreview,
      ),
    );
  }

  String get _desktopChatPaneWidthKey =>
      'project_chat_desktop_sidebar_width:${widget.projectId}';

  String get _desktopChatPaneCollapsedKey =>
      'project_chat_desktop_sidebar_collapsed:${widget.projectId}';

  double _clampDesktopChatPaneWidth(double width, double totalWidth) {
    final maxAllowed = (totalWidth - _desktopPrimaryPaneMinWidth).clamp(
      _desktopChatPaneMinWidth,
      _desktopChatPaneMaxWidth,
    );
    return width.clamp(_desktopChatPaneMinWidth, maxAllowed);
  }

  Future<void> _loadDesktopChatPaneWidth() async {
    try {
      final raw = _storageService.getString(_desktopChatPaneWidthKey)?.trim();
      final parsed = raw == null || raw.isEmpty ? null : double.tryParse(raw);
      if (parsed == null || !mounted) return;
      setState(() {
        _desktopChatPaneWidth = parsed.clamp(
          _desktopChatPaneMinWidth,
          _desktopChatPaneMaxWidth,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadDesktopChatPaneCollapsed() async {
    try {
      final value = _storageService.getBool(_desktopChatPaneCollapsedKey);
      if (value == null || !mounted) return;
      setState(() {
        _desktopChatPaneCollapsed = value;
      });
    } catch (_) {}
  }

  Future<void> _persistDesktopChatPaneWidth(double value) async {
    try {
      await _storageService.setString(
        _desktopChatPaneWidthKey,
        value.toStringAsFixed(1),
      );
    } catch (_) {}
  }

  Future<void> _persistDesktopChatPaneCollapsed(bool value) async {
    try {
      await _storageService.setBool(_desktopChatPaneCollapsedKey, value);
    } catch (_) {}
  }

  void _setDesktopChatPaneWidthForViewport(
    double next,
    double totalWidth, {
    bool persist = true,
  }) {
    final clamped = _clampDesktopChatPaneWidth(next, totalWidth);
    if ((_desktopChatPaneWidth - clamped).abs() < 0.5) return;
    if (mounted) {
      setState(() {
        _desktopChatPaneWidth = clamped;
      });
    } else {
      _desktopChatPaneWidth = clamped;
    }
    if (persist) {
      unawaited(_persistDesktopChatPaneWidth(clamped));
    }
  }

  void _resetDesktopChatPaneWidth(double totalWidth) {
    _setDesktopChatPaneWidthForViewport(
      _desktopChatPaneDefaultWidth,
      totalWidth,
    );
  }

  void _setDesktopChatPaneCollapsed(bool next) {
    if (_desktopChatPaneCollapsed == next) return;
    if (mounted) {
      setState(() {
        _desktopChatPaneCollapsed = next;
      });
    } else {
      _desktopChatPaneCollapsed = next;
    }
    unawaited(_persistDesktopChatPaneCollapsed(next));
  }

  double _effectiveDesktopChatPaneWidth(
    double totalWidth, {
    double? preferredWidth,
  }) {
    return _clampDesktopChatPaneWidth(
      preferredWidth ?? _desktopChatPaneWidth,
      totalWidth,
    );
  }

  Future<void> _initializeChat();
  void _sendChatMessage(String text);
  void _sendFirstMessage(String text);

  // Shared helpers implemented by logic mixin; UI mixin depends on them.
  // ignore: unused_element
  Future<void> _refreshWorkspaceStatus({required bool bypassCache});
  Future<void> _loadMoreHistory();
  Future<void> _loadChatHistory();
  Future<void> _retryMessage(ChatMessage message);
  Future<void> _handleModelChanged(String modelId);
  Future<void> _handleEngineChanged(ChatEngineMode mode);
  Future<void> _persistChatDraft(String value);
  void _handleProjectFileLinkTap(ProjectFileLinkTarget target);

  // Outbox actions (implemented by logic mixin; UI passes these into widgets).
  void _outboxClear();
  void _outboxDelete(OutboxItem item);
  void _outboxUpdate(OutboxItem item, String nextPrompt);

  Future<void> triggerPreviewRedeploy();
  Future<void> reconnectWebSocket();
}
