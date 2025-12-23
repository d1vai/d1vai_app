part of '../../project_chat/project_chat_tab.dart';

abstract class _ProjectChatTabStateBase extends State<ProjectChatTab>
    with AutomaticKeepAliveClientMixin {
  final ChatService _chatService = ChatService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  final Map<String, MessageStatus> _messageStatuses = {};

  bool _isChatLoading = false;
  bool _isLoadingHistory = false;
  String? _currentSessionId;
  bool _historyLoaded = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  DateTime? _oldestMessageAt;

  // Workspace state (align with web BigChat)
  WorkspaceStateInfo? _workspaceState;
  WorkspacePhase _workspacePhase = WorkspacePhase.unknown;
  String? _workspaceError;
  Timer? _workspacePollTimer;
  bool _workspacePollInFlight = false;
  bool _workspaceWarmupInFlight = false;
  int _workspacePollErrorStreak = 0;

  // WebSocket runtime (similar responsibilities to web's wsManager + useWebSocket)
  String? _activeWsSessionId;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualWsClose = false;
  bool _autoConnectDisabled = false;
  final Set<String> _seenWsKeys = <String>{};

  // Mobile chat bottom sheet state
  bool _showMobileChat = false;

  // Sub-tab state (Preview / Code / Env)
  int _currentChatTabIndex = 0;

  // Environment variables for Env sub-tab
  List<EnvVar> _envVars = [];
  bool _isLoadingEnvVars = false;

  @override
  bool get wantKeepAlive => true;

  /// 允许其他 Tab 触发首条消息并自动切换到 Preview 子标签
  void sendInitialPrompt(String text) {
    _currentChatTabIndex = 0;
    _sendFirstMessage(text);
  }

  Future<void> _initializeChat();
  Future<void> _loadEnvVars();
  void _sendChatMessage(String text);
  void _sendFirstMessage(String text);

  // Shared helpers implemented by logic mixin; UI mixin depends on them.
  Future<void> _refreshWorkspaceStatus({required bool bypassCache});
  Future<void> _loadMoreHistory();
  Future<void> _retryMessage(ChatMessage message);
}
