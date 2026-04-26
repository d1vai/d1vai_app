part of '../../project_chat/project_chat_tab.dart';

mixin _ProjectChatTabUI on _ProjectChatTabStateBase {
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  List<String> _workspaceWarmupTips() {
    final loc = AppLocalizations.of(context);
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return <String>[
          loc?.translate('workspace_tip_online_short') ?? 'Online',
          loc?.translate('workspace_tip_sync_model_short') ?? 'Syncing model',
          loc?.translate('chat_status_ready') ?? 'Ready',
        ];
      case WorkspacePhase.starting:
        return <String>[
          loc?.translate('workspace_tip_checking_short') ?? 'Checking',
          loc?.translate('workspace_tip_starting_workspace_short') ??
              'Starting workspace',
          loc?.translate('workspace_tip_opening_session_short') ??
              'Opening session',
        ];
      case WorkspacePhase.syncing:
        return <String>[
          loc?.translate('workspace_tip_online_short') ?? 'Online',
          loc?.translate('workspace_tip_sync_files_short') ?? 'Syncing files',
          loc?.translate('workspace_tip_opening_session_short') ??
              'Opening session',
        ];
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        return <String>[
          loc?.translate('workspace_tip_sleeping_short') ?? 'Sleeping',
          loc?.translate('workspace_tip_waking_up_short') ?? 'Waking up',
          loc?.translate('workspace_tip_opening_session_short') ??
              'Opening session',
        ];
      case WorkspacePhase.error:
        return <String>[
          loc?.translate('workspace_tip_start_failed_short') ?? 'Start failed',
          loc?.translate('workspace_tip_retrying_short') ?? 'Retrying',
          loc?.translate('workspace_tip_opening_session_short') ??
              'Opening session',
        ];
      case WorkspacePhase.unknown:
        return <String>[
          loc?.translate('workspace_tip_checking_short') ?? 'Checking',
          loc?.translate('workspace_tip_preparing_short') ?? 'Preparing',
          loc?.translate('workspace_tip_opening_session_short') ??
              'Opening session',
        ];
    }
  }

  String _statusLabel() {
    final loc = AppLocalizations.of(context);
    if (_isDeploying) return loc?.translate('deploying_title') ?? 'Deploying';
    if (_outboxItems.isNotEmpty) {
      if (_outboxMode == OutboxMode.dispatching) {
        return loc?.translate('chat_status_sending') ?? 'Sending';
      }
      if (_outboxMode == OutboxMode.pausedError) {
        return loc?.translate('chat_status_queue_paused') ?? 'Queue paused';
      }
      if (_outboxMode == OutboxMode.waitingWorkspace) {
        return loc?.translate('chat_status_waking') ?? 'Waking';
      }
      if (_outboxMode == OutboxMode.waitingModel) {
        return loc?.translate('chat_status_loading_model') ?? 'Loading model';
      }
      if (_outboxMode == OutboxMode.waitingTask) {
        return loc?.translate('chat_status_waiting') ?? 'Waiting';
      }
      return _outboxItems.length > 1
          ? (loc?.translate('chat_status_queued_count') ?? 'Queued {count}')
                .replaceAll('{count}', '${_outboxItems.length}')
          : (loc?.translate('chat_status_queued') ?? 'Queued');
    }
    final working =
        _isChatLoading ||
        _wsConnState == WsConnectionState.connecting ||
        (_wsConnState == WsConnectionState.connected &&
            !_autoConnectDisabled &&
            !_sessionDone &&
            !_sessionError &&
            (_activeWsSessionId ?? '').trim().isNotEmpty);
    if (_sessionError) return loc?.translate('chat_status_check') ?? 'Check';
    if (_sessionDone) {
      final finished = _lastSessionFinishedAt;
      if (finished != null &&
          DateTime.now().difference(finished) < const Duration(seconds: 8)) {
        return loc?.translate('chat_status_ready') ?? 'Ready';
      }
      return loc?.translate('chat_status_done') ?? 'Done';
    }
    if (_sessionThinking) {
      return loc?.translate('chat_status_thinking') ?? 'Thinking';
    }
    if (working) return loc?.translate('chat_status_working') ?? 'Working';
    if (_workspacePhase == WorkspacePhase.error) {
      return loc?.translate('workspace_title') ?? 'Workspace';
    }
    if (_workspacePhase != WorkspacePhase.ready) {
      return loc?.translate('chat_status_preparing') ?? 'Preparing';
    }
    if (_isLoadingModels || _isSwitchingModel) {
      return loc?.translate('chat_status_loading_model') ?? 'Loading model';
    }
    return loc?.translate('chat_status_ready') ?? 'Ready';
  }

  String _statusToken() {
    if (_isDeploying) return 'deploying';
    if (_outboxItems.isNotEmpty) {
      if (_outboxMode == OutboxMode.dispatching) return 'sending';
      if (_outboxMode == OutboxMode.pausedError) return 'queue_paused';
      if (_outboxMode == OutboxMode.waitingWorkspace) return 'waking';
      if (_outboxMode == OutboxMode.waitingModel) return 'loading_model';
      if (_outboxMode == OutboxMode.waitingTask) return 'waiting';
      return 'queued';
    }
    final working =
        _isChatLoading ||
        _wsConnState == WsConnectionState.connecting ||
        (_wsConnState == WsConnectionState.connected &&
            !_autoConnectDisabled &&
            !_sessionDone &&
            !_sessionError &&
            (_activeWsSessionId ?? '').trim().isNotEmpty);
    if (_sessionError) return 'error';
    if (_sessionDone) return 'done';
    if (_sessionThinking) return 'thinking';
    if (working) return 'working';
    if (_workspacePhase == WorkspacePhase.error) return 'workspace';
    if (_workspacePhase != WorkspacePhase.ready) return 'preparing';
    if (_isLoadingModels || _isSwitchingModel) return 'loading_model';
    return 'ready';
  }

  String? _statusBannerTitle() {
    final loc = AppLocalizations.of(context);
    if (_isDeploying) return loc?.translate('deploying_title') ?? 'Deploying';
    if (_workspaceWarmupVisible) {
      return _workspaceWarmupCompleted
          ? (loc?.translate('workspace_banner_ready') ?? 'Workspace ready')
          : (loc?.translate('workspace_banner_starting') ??
                'Starting workspace');
    }
    if (_workspacePhase == WorkspacePhase.error) {
      return loc?.translate('workspace_banner_issue') ?? 'Workspace issue';
    }
    if (_outboxItems.isNotEmpty) {
      if (_outboxMode == OutboxMode.pausedError) {
        return loc?.translate('chat_status_queue_paused') ?? 'Queue paused';
      }
      if (_outboxMode == OutboxMode.dispatching) {
        return loc?.translate('chat_banner_sending_next') ?? 'Sending next';
      }
      if (_outboxMode == OutboxMode.waitingWorkspace) {
        return loc?.translate('chat_banner_waking_workspace') ??
            'Waking workspace';
      }
      if (_outboxMode == OutboxMode.waitingModel) {
        return loc?.translate('chat_status_loading_model') ?? 'Loading model';
      }
      if (_outboxMode == OutboxMode.waitingTask) {
        return loc?.translate('chat_banner_waiting_current_run') ??
            'Waiting for current run';
      }
      return _outboxItems.length > 1
          ? (loc?.translate('chat_banner_queued_count') ?? '{count} queued')
                .replaceAll('{count}', '${_outboxItems.length}')
          : (loc?.translate('chat_banner_queued_one') ?? '1 queued');
    }
    if (_sessionThinking) {
      return loc?.translate('chat_status_thinking') ?? 'Thinking';
    }
    if (_wsConnState == WsConnectionState.connecting) {
      return loc?.translate('chat_banner_reconnecting') ?? 'Reconnecting';
    }
    if (_sessionDone &&
        _lastSessionFinishedAt != null &&
        DateTime.now().difference(_lastSessionFinishedAt!) <
            const Duration(seconds: 8)) {
      return loc?.translate('chat_status_done') ?? 'Done';
    }
    if (_isLoadingModels || _isSwitchingModel) {
      return loc?.translate('chat_status_loading_model') ?? 'Loading model';
    }
    switch (_workspacePhase) {
      case WorkspacePhase.ready:
        return null;
      case WorkspacePhase.starting:
      case WorkspacePhase.syncing:
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
      case WorkspacePhase.unknown:
      case WorkspacePhase.error:
        return loc?.translate('workspace_title') ?? 'Workspace';
    }
  }

  String? _statusBannerMessage() {
    final loc = AppLocalizations.of(context);
    if (_isDeploying) {
      final framework = (_deployFramework ?? '').trim();
      return framework.isEmpty
          ? (loc?.translate('chat_banner_preview_rebuilding') ??
                'Preview is rebuilding.')
          : (loc?.translate('chat_banner_preview_rebuilding_framework') ??
                    '{framework} preview is rebuilding.')
                .replaceAll('{framework}', framework);
    }
    if (_workspaceWarmupVisible) {
      return _workspaceWarmupMessage ??
          (loc?.translate('workspace_banner_starting_now') ??
              'Starting now. Your message will send next.');
    }
    if (_workspacePhase == WorkspacePhase.error) {
      final error = (_workspaceError ?? '').trim();
      return error.isEmpty
          ? (loc?.translate('workspace_banner_retrying_background') ??
                'Start failed. Retrying in the background.')
          : error;
    }
    if (_outboxItems.isNotEmpty) {
      final firstPrompt = _outboxItems.first.prompt.trim();
      if (_outboxMode == OutboxMode.pausedError) {
        return loc?.translate('chat_banner_one_prompt_failed') ??
            'One queued prompt failed.';
      }
      if (_outboxMode == OutboxMode.dispatching) {
        return firstPrompt.isEmpty
            ? (loc?.translate('chat_banner_sending_next_prompt') ??
                  'Sending next prompt.')
            : firstPrompt;
      }
      if (_outboxMode == OutboxMode.waitingWorkspace) {
        return loc?.translate('chat_banner_queue_resume_workspace') ??
            'Queue resumes when the workspace is ready.';
      }
      if (_outboxMode == OutboxMode.waitingModel) {
        return loc?.translate('chat_banner_queue_resume_model') ??
            'Queue resumes when the model is ready.';
      }
      if (_outboxMode == OutboxMode.waitingTask) {
        return loc?.translate('chat_banner_queue_resume_run') ??
            'Queue resumes after the current run.';
      }
      return firstPrompt.isEmpty
          ? (loc?.translate('chat_banner_next_prompt_queued') ??
                'Next prompt is queued.')
          : firstPrompt;
    }
    if (_sessionThinking) {
      return loc?.translate('chat_banner_working_request') ??
          'Working through your request.';
    }
    if (_wsConnState == WsConnectionState.connecting) {
      return loc?.translate('chat_banner_restoring_output') ??
          'Restoring live output.';
    }
    if (_sessionDone &&
        _lastSessionFinishedAt != null &&
        DateTime.now().difference(_lastSessionFinishedAt!) <
            const Duration(seconds: 8)) {
      return loc?.translate('chat_banner_send_next_message') ??
          'You can send the next message.';
    }
    if (_isLoadingModels || _isSwitchingModel) {
      return loc?.translate('chat_banner_updating_model') ??
          'Updating model settings.';
    }
    switch (_workspacePhase) {
      case WorkspacePhase.starting:
        return loc?.translate('workspace_banner_starting_message') ??
            'Starting workspace.';
      case WorkspacePhase.syncing:
        return loc?.translate('workspace_banner_syncing_files') ??
            'Syncing files.';
      case WorkspacePhase.standby:
      case WorkspacePhase.archived:
        return loc?.translate('workspace_banner_sleeping_needed') ??
            'Sleeping until needed.';
      case WorkspacePhase.unknown:
        return loc?.translate('workspace_banner_checking_status') ??
            'Checking status.';
      case WorkspacePhase.ready:
      case WorkspacePhase.error:
        return null;
    }
  }

  IconData _statusBannerIcon() {
    if (_isDeploying) return Icons.rocket_launch_outlined;
    if (_workspaceWarmupVisible) return Icons.memory_rounded;
    if (_workspacePhase == WorkspacePhase.error) {
      return Icons.error_outline_rounded;
    }
    if (_outboxItems.isNotEmpty) {
      if (_outboxMode == OutboxMode.pausedError) {
        return Icons.pause_circle_outline_rounded;
      }
      if (_outboxMode == OutboxMode.dispatching) return Icons.send_rounded;
      if (_outboxMode == OutboxMode.waitingWorkspace) {
        return Icons.cloud_sync_outlined;
      }
      if (_outboxMode == OutboxMode.waitingModel) return Icons.tune_rounded;
      if (_outboxMode == OutboxMode.waitingTask) {
        return Icons.hourglass_top_rounded;
      }
      return Icons.queue_rounded;
    }
    if (_sessionThinking) return Icons.psychology_alt_outlined;
    if (_wsConnState == WsConnectionState.connecting) {
      return Icons.wifi_tethering_rounded;
    }
    if (_sessionDone) return Icons.check_circle_outline_rounded;
    return Icons.info_outline_rounded;
  }

  Color _statusBannerAccent(BuildContext context) {
    final theme = Theme.of(context);
    if (_workspacePhase == WorkspacePhase.error || _sessionError) {
      return theme.colorScheme.error;
    }
    if (_isDeploying) return theme.colorScheme.tertiary;
    if (_sessionDone) return Colors.green;
    return theme.colorScheme.primary;
  }

  bool _statusBannerBusy() {
    return _isDeploying ||
        _workspaceWarmupVisible ||
        _sessionThinking ||
        _wsConnState == WsConnectionState.connecting ||
        _outboxMode == OutboxMode.dispatching ||
        _outboxMode == OutboxMode.waitingWorkspace ||
        _outboxMode == OutboxMode.waitingModel ||
        _outboxMode == OutboxMode.waitingTask;
  }

  List<QuickActionItem> _quickActions() {
    if (_workspacePhase == WorkspacePhase.error) {
      return const <QuickActionItem>[
        QuickActionItem(
          label: 'Check workspace',
          icon: Icons.memory_rounded,
          prompt:
              'Check the current workspace status and tell me what is wrong.',
        ),
        QuickActionItem(
          label: 'Recover startup',
          icon: Icons.build_circle_outlined,
          prompt:
              'Help me recover the workspace startup failure with the smallest safe fix.',
        ),
        QuickActionItem(
          label: 'Summarize errors',
          icon: Icons.error_outline_rounded,
          prompt: 'Summarize the latest errors and what I should do next.',
        ),
      ];
    }
    if ((_previewUrl ?? '').trim().isEmpty) {
      return const <QuickActionItem>[
        QuickActionItem(
          label: 'Deploy preview',
          icon: Icons.rocket_launch_outlined,
          prompt: 'Help me get a preview deployed for this project.',
        ),
        QuickActionItem(
          label: 'Inspect project',
          icon: Icons.search_rounded,
          prompt:
              'Inspect this project and tell me what it currently contains.',
        ),
        QuickActionItem(
          label: 'Suggest first step',
          icon: Icons.flag_outlined,
          prompt: 'What is the best next step to make this project usable?',
        ),
      ];
    }
    if (_outboxItems.isNotEmpty) {
      return const <QuickActionItem>[
        QuickActionItem(
          label: 'Review queue',
          icon: Icons.queue_rounded,
          prompt:
              'Review the queued prompts and tell me if they can be merged.',
        ),
        QuickActionItem(
          label: 'Refine request',
          icon: Icons.edit_note_rounded,
          prompt:
              'Help me rewrite my next request so it is clearer and more specific.',
        ),
        QuickActionItem(
          label: 'Summarize progress',
          icon: Icons.splitscreen_rounded,
          prompt:
              'Summarize what has already finished and what is still queued.',
        ),
      ];
    }
    return const <QuickActionItem>[
      QuickActionItem(
        label: 'Debug issue',
        icon: Icons.bug_report_outlined,
        prompt: 'Help me debug the current issue in this project.',
      ),
      QuickActionItem(
        label: 'Explain code',
        icon: Icons.code_rounded,
        prompt: 'Explain the relevant code in this project.',
      ),
      QuickActionItem(
        label: 'Review changes',
        icon: Icons.rate_review_outlined,
        prompt: 'Review the current project changes and point out risks.',
      ),
      QuickActionItem(
        label: 'Improve UX',
        icon: Icons.auto_awesome_rounded,
        prompt: 'Suggest the most valuable UX improvements for this project.',
      ),
    ];
  }

  String _quickActionsTitle() {
    if (_workspacePhase == WorkspacePhase.error) return 'Recovery';
    if ((_previewUrl ?? '').trim().isEmpty) return 'Preview';
    if (_outboxItems.isNotEmpty) return 'Queue';
    return 'Shortcuts';
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
              statusToken: _statusToken(),
              statusIsError: _sessionError,
              bannerTitle: _statusBannerTitle(),
              bannerMessage: _statusBannerMessage(),
              bannerIcon: _statusBannerIcon(),
              bannerAccent: _statusBannerAccent(context),
              bannerBusy: _statusBannerBusy(),
              messageStatuses: _messageStatuses,
              onRetry: _retryMessage,
              onLoadMore: _loadMoreHistory,
              hasMoreHistory: _hasMoreHistory,
              isLoadingMore: _isLoadingMoreHistory,
              scrollController: _chatScrollController,
              inputController: _chatInputController,
              inputFocusNode: _chatInputFocusNode,
              onInputChanged: (text) => unawaited(_persistChatDraft(text)),
              quickActions: _quickActions(),
              quickActionsTitle: _quickActionsTitle(),
              onSendMessage: _sendChatMessage,
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
              models: _availableModels,
              selectedModelId: _selectedModelId,
              selectedEngineMode: _selectedEngineMode,
              onModelChanged: (v) => unawaited(_handleModelChanged(v)),
              onEngineChanged: (v) => unawaited(_handleEngineChanged(v)),
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
            secondaryLabel: _statusBannerTitle(),
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
            secondaryLabel: _statusBannerTitle(),
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
      return NoPreviewAvailableView(
        onRedeploy: () => unawaited(triggerPreviewRedeploy()),
        onOpenCode: () {
          setState(() {
            _currentChatTabIndex = 1;
          });
        },
        isDeploying: _isDeploying,
      );
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
      return NoPreviewAvailableView(
        onRedeploy: () => unawaited(triggerPreviewRedeploy()),
        onOpenCode: () {
          setState(() {
            _currentChatTabIndex = 1;
          });
        },
        isDeploying: _isDeploying,
      );
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
