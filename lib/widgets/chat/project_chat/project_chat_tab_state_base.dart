part of '../../project_chat/project_chat_tab.dart';

enum WsConnectionState { idle, connecting, connected, failed }

abstract class _ProjectChatTabStateBase extends State<ProjectChatTab>
    with AutomaticKeepAliveClientMixin {
  final ChatService _chatService = ChatService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final ModelConfigService _modelConfigService = ModelConfigService();
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  final Map<String, MessageStatus> _messageStatuses = {};
  final D1vaiService _d1vaiService = D1vaiService();

  bool _isChatLoading = false;
  bool _isLoadingHistory = false;
  String? _currentSessionId;
  bool _historyLoaded = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  DateTime? _oldestMessageAt;

  // Session UI phase (align with web's mobileStatusLabel)
  bool _sessionThinking = false;
  bool _sessionDone = false;
  bool _sessionError = false;
  Timer? _thinkingClearTimer;

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
  WsConnectionState _wsConnState = WsConnectionState.idle;

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

  // Preview runtime
  String? _previewUrl;
  int _previewKey = 0;

  // Deployment runtime (for preview redeploy + WS deployment frames)
  bool _isDeploying = false;
  String? _deployFramework;
  Timer? _deployAutoClearTimer;
  DateTime? _lastDeployCompletedAt;

  @override
  bool get wantKeepAlive => true;

  /// 允许其他 Tab 触发首条消息并自动切换到 Preview 子标签
  void sendInitialPrompt(String text) {
    _currentChatTabIndex = 0;
    _sendFirstMessage(text);
  }

  Future<void> _initializeChat();
  void _sendChatMessage(String text);
  void _sendFirstMessage(String text);

  // Shared helpers implemented by logic mixin; UI mixin depends on them.
  Future<void> _refreshWorkspaceStatus({required bool bypassCache});
  Future<void> _loadMoreHistory();
  Future<void> _retryMessage(ChatMessage message);
  Future<void> _handleModelChanged(String modelId);

  // Outbox actions (implemented by logic mixin; UI passes these into widgets).
  void _outboxClear();
  void _outboxDelete(OutboxItem item);
  void _outboxUpdate(OutboxItem item, String nextPrompt);

  Future<void> triggerPreviewRedeploy();
  Future<void> reconnectWebSocket();
}
