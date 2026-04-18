part of '../../project_chat/project_chat_tab.dart';

mixin _ProjectChatTabUI on _ProjectChatTabStateBase {
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  List<String> _workspaceWarmupTips() {
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return const <String>[
          'Workspace online',
          'Syncing model settings',
          'Ready to send',
        ];
      case WorkspacePhase.starting:
        return const <String>[
          'Checking workspace status',
          'Starting workspace container',
          'Preparing execution session',
        ];
      case WorkspacePhase.syncing:
        return const <String>[
          'Workspace online',
          'Syncing files and runtime',
          'Preparing execution session',
        ];
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        return const <String>[
          'Workspace sleeping',
          'Waking workspace up',
          'Preparing execution session',
        ];
      case WorkspacePhase.error:
        return const <String>[
          'Workspace warmup failed',
          'Retrying workspace startup',
          'Preparing execution session',
        ];
      case WorkspacePhase.unknown:
        return const <String>[
          'Checking workspace status',
          'Preparing workspace',
          'Preparing execution session',
        ];
    }
  }

  Color _workspaceDotColor() {
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return Colors.green;
      case WorkspacePhase.starting:
        return Colors.amber;
      case WorkspacePhase.syncing:
        return Colors.purple;
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        return Colors.grey;
      case WorkspacePhase.error:
        return Colors.red;
      case WorkspacePhase.unknown:
        return Colors.grey;
    }
  }

  String _workspaceTooltip() {
    final parts = <String>[];
    final raw = _workspaceState?.status;
    if (raw != null && raw.trim().isNotEmpty) {
      parts.add(raw.trim());
    }
    final ip = _workspaceState?.ip;
    final port = _workspaceState?.port;
    if (ip != null && port != null) {
      parts.add('$ip:$port');
    }
    if (_workspaceError != null && _workspaceError!.trim().isNotEmpty) {
      parts.add(_workspaceError!);
    }
    return raw != null && raw.trim().isNotEmpty
        ? raw.trim()
        : (parts.isEmpty ? 'Workspace' : parts.join(' · '));
  }

  String _statusLabel() {
    // Align with d1vai mobileStatusLabel.
    final working =
        _isChatLoading ||
        _wsConnState == WsConnectionState.connecting ||
        (_wsConnState == WsConnectionState.connected &&
            !_autoConnectDisabled &&
            !_sessionDone &&
            !_sessionError &&
            (_activeWsSessionId ?? '').trim().isNotEmpty);
    return _isDeploying
        ? 'Deploying'
        : _sessionError
        ? 'Error'
        : _sessionDone
        ? 'Done'
        : working
        ? 'Working'
        : _sessionThinking
        ? 'Thinking'
        : 'Ready';
  }

  void _openMobileChat() {
    HapticFeedback.lightImpact();
    setState(() {
      _showMobileChat = true;
      _mobileChatSheetExtent = 0.7;
      _mobileChatSheetStage = _sheetStageForExtent(_mobileChatSheetExtent);
    });
    _initializeChat();
  }

  void _closeMobileChat() {
    HapticFeedback.lightImpact();
    setState(() {
      _showMobileChat = false;
    });
  }

  int _sheetStageForExtent(double extent) {
    if (extent >= 0.88) return 2;
    if (extent >= 0.66) return 1;
    return 0;
  }

  bool _handleChatSheetNotification(
    DraggableScrollableNotification notification,
  ) {
    final nextExtent = notification.extent.clamp(0.0, 1.0);
    final nextStage = _sheetStageForExtent(nextExtent);
    final extentChanged = (_mobileChatSheetExtent - nextExtent).abs() > 0.015;
    final stageChanged = nextStage != _mobileChatSheetStage;

    if (!extentChanged && !stageChanged) return false;

    if (stageChanged) {
      HapticFeedback.selectionClick();
    }

    if (!mounted) {
      _mobileChatSheetExtent = nextExtent;
      _mobileChatSheetStage = nextStage;
      return false;
    }

    setState(() {
      _mobileChatSheetExtent = nextExtent;
      _mobileChatSheetStage = nextStage;
    });
    return false;
  }

  Widget _buildChatSheetOverlay(BuildContext context, {double? maxWidth}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final expandT = ((_mobileChatSheetExtent - 0.5) / 0.45).clamp(0.0, 1.0);
    final scrimAlpha = (0.34 + 0.18 * expandT) * (isDark ? 0.88 : 1.0);
    final radius = lerpDouble(26, 16, expandT) ?? 18;
    final borderAlpha = isDark ? 0.76 - 0.16 * expandT : 0.9 - 0.2 * expandT;
    final glowAlpha = isDark ? 0.18 + 0.08 * expandT : 0.08 + 0.06 * expandT;

    final sheet = NotificationListener<DraggableScrollableNotification>(
      onNotification: _handleChatSheetNotification,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: maxWidth == null ? 0.5 : 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(
                  alpha: borderAlpha,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(
                    alpha: isDark
                        ? 0.28 + 0.04 * expandT
                        : 0.12 + 0.03 * expandT,
                  ),
                  blurRadius: 26,
                  offset: const Offset(0, -10),
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: glowAlpha),
                  blurRadius: isDark ? 24 : 18,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ChatBottomSheet(
              messages: _chatMessages,
              isLoading: _isChatLoading,
              isLoadingHistory: _isLoadingHistory,
              isDeploying: _isDeploying,
              outboxItems: _outboxItems,
              outboxMode: _outboxMode,
              onOutboxClear: _outboxClear,
              onOutboxDelete: _outboxDelete,
              onOutboxUpdate: _outboxUpdate,
              heroTag: 'project-chat-messages-${widget.projectId}',
              statusLabel: _statusLabel(),
              statusIsError: _sessionError,
              messageStatuses: _messageStatuses,
              onRetry: _retryMessage,
              onLoadMore: _loadMoreHistory,
              hasMoreHistory: _hasMoreHistory,
              isLoadingMore: _isLoadingMoreHistory,
              scrollController: _chatScrollController,
              onSendMessage: _sendChatMessage,
              onRedeploy: () => unawaited(triggerPreviewRedeploy()),
              onOpenFullScreen: () {
                GoRouter.of(context).push('/projects/${widget.projectId}/chat');
              },
              onClose: _closeMobileChat,
              isModelReady: _selectedModelId.trim().isNotEmpty,
              isModelLoading:
                  _isLoadingModels ||
                  _isSwitchingModel ||
                  _workspacePhase != WorkspacePhase.ready ||
                  !_hasLoadedModelConfig,
            ),
          );
        },
      ),
    );

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, appear, _) {
          return GestureDetector(
            onTap: _closeMobileChat,
            child: Container(
              color: Colors.black.withValues(alpha: scrimAlpha * appear),
              child: GestureDetector(
                onTap: () {},
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: Offset(0, (1 - appear) * 28),
                    child: maxWidth == null
                        ? sheet
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: sheet,
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = _isMobile(context);
    final child = isMobile
        ? _buildChatTabMobile(context)
        : _buildChatTabDesktop(context);
    return Stack(
      children: [
        child,
        if (_workspaceWarmupVisible) _buildWorkspaceWarmupOverlay(context),
      ],
    );
  }

  Widget _buildWorkspaceWarmupOverlay(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: IgnorePointer(
        ignoring: true,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((_workspaceWarmupMessage ?? '').trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _workspaceWarmupMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ProgressWidget(
                tipList: _workspaceWarmupTips(),
                completed: _workspaceWarmupCompleted,
                preCompleteDuration: const Duration(seconds: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTabMobile(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            ProjectChatTopBar(
              currentIndex: _currentChatTabIndex,
              onTabSelected: (index) {
                setState(() {
                  _currentChatTabIndex = index;
                });
              },
              onRefreshPreview: _handleRefreshPreview,
              onOpenInNewTab: _handleOpenInNewTab,
              workspaceDotColor: _workspaceDotColor(),
              workspaceTooltip: _workspaceTooltip(),
              onWorkspacePressed: () {
                unawaited(_refreshWorkspaceStatus(bypassCache: true));
              },
              models: _availableModels,
              selectedModelId: _selectedModelId,
              isModelLoading:
                  _isLoadingModels ||
                  _workspacePhase != WorkspacePhase.ready ||
                  !_hasLoadedModelConfig,
              isModelSwitching: _isSwitchingModel,
              onModelChanged: (v) => unawaited(_handleModelChanged(v)),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentChatTabIndex,
                children: [_buildChatPreviewTabMobile(), _buildChatCodeTab()],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: _openMobileChat,
            statusLabel: _statusLabel(),
            isError: _sessionError,
            isDone: _sessionDone,
            isWorking:
                _isChatLoading ||
                _wsConnState == WsConnectionState.connecting ||
                (_wsConnState == WsConnectionState.connected &&
                    !_autoConnectDisabled &&
                    !_sessionDone &&
                    !_sessionError &&
                    (_activeWsSessionId ?? '').trim().isNotEmpty),
            isThinking: _sessionThinking,
            isDeploying: _isDeploying,
          ),
        ),
        if (_showMobileChat) _buildChatSheetOverlay(context),
      ],
    );
  }

  Widget _buildChatTabDesktop(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            ProjectChatTopBar(
              currentIndex: _currentChatTabIndex,
              onTabSelected: (index) {
                setState(() {
                  _currentChatTabIndex = index;
                });
              },
              onRefreshPreview: _handleRefreshPreview,
              onOpenInNewTab: _handleOpenInNewTab,
              workspaceDotColor: _workspaceDotColor(),
              workspaceTooltip: _workspaceTooltip(),
              onWorkspacePressed: () {
                unawaited(_refreshWorkspaceStatus(bypassCache: true));
              },
              models: _availableModels,
              selectedModelId: _selectedModelId,
              isModelLoading:
                  _isLoadingModels ||
                  _workspacePhase != WorkspacePhase.ready ||
                  !_hasLoadedModelConfig,
              isModelSwitching: _isSwitchingModel,
              onModelChanged: (v) => unawaited(_handleModelChanged(v)),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentChatTabIndex,
                children: [_buildChatPreviewTab(), _buildChatCodeTab()],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: _openMobileChat,
            statusLabel: _statusLabel(),
            isError: _sessionError,
            isDone: _sessionDone,
            isWorking:
                _isChatLoading ||
                _wsConnState == WsConnectionState.connecting ||
                (_wsConnState == WsConnectionState.connected &&
                    !_autoConnectDisabled &&
                    !_sessionDone &&
                    !_sessionError &&
                    (_activeWsSessionId ?? '').trim().isNotEmpty),
            isThinking: _sessionThinking,
            isDeploying: _isDeploying,
          ),
        ),
        if (_showMobileChat) _buildChatSheetOverlay(context, maxWidth: 720),
      ],
    );
  }

  Widget _buildChatPreviewTabMobile() {
    final theme = Theme.of(context);
    final previewUrl = _previewUrl;
    if (previewUrl == null || previewUrl.trim().isEmpty) {
      return const NoPreviewAvailableView();
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: ProjectChatWebView(
              key: ValueKey('preview-${previewUrl.trim()}-$_previewKey'),
              url: previewUrl.trim(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatPreviewTab() {
    final theme = Theme.of(context);
    final previewUrl = _previewUrl;
    if (previewUrl == null || previewUrl.trim().isEmpty) {
      return const NoPreviewAvailableView();
    }

    return Column(
      children: [
        ProjectChatPreviewHeader(
          previewUrl: previewUrl.trim(),
          onRefreshPreview: _handleRefreshPreview,
          onOpenInNewTab: _handleOpenInNewTab,
        ),
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: ProjectChatWebView(
              key: ValueKey('preview-${previewUrl.trim()}-$_previewKey'),
              url: previewUrl.trim(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatCodeTab() {
    return ProjectChatCodeTab(
      projectId: widget.projectId,
      onAsk: (question) {
        _sendFirstMessage(question);
        setState(() {
          _currentChatTabIndex = 0;
        });
      },
    );
  }

  void _handleRefreshPreview() {
    setState(() {
      _previewKey += 1;
      _currentChatTabIndex = 0;
    });
  }

  void _handleOpenInNewTab() {
    final previewUrl = _previewUrl;
    if (previewUrl == null || previewUrl.trim().isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'No Preview URL',
        message: 'Preview URL is not available',
      );
      return;
    }

    final uri = Uri.tryParse(previewUrl.trim());
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
