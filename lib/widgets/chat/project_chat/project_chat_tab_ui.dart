part of '../../project_chat/project_chat_tab.dart';

mixin _ProjectChatTabUI on _ProjectChatTabStateBase {
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
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
      parts.add('status=$raw');
    }
    final ip = _workspaceState?.ip;
    final port = _workspaceState?.port;
    if (ip != null && port != null) {
      parts.add('$ip:$port');
    }
    if (_workspaceError != null && _workspaceError!.trim().isNotEmpty) {
      parts.add(_workspaceError!);
    }
    return parts.isEmpty ? 'Workspace' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = _isMobile(context);

    if (isMobile) {
      return _buildChatTabMobile(context);
    }
    return _buildChatTabDesktop(context);
  }

  Widget _buildChatTabMobile(BuildContext context) {
    final theme = Theme.of(context);

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
            ),
            Expanded(
              child: IndexedStack(
                index: _currentChatTabIndex,
                children: [
                  _buildChatPreviewTabMobile(),
                  _buildChatCodeTab(),
                  _buildChatEnvTab(),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: () {
              setState(() {
                _showMobileChat = true;
              });
              _initializeChat();
            },
            statusLabel: _isChatLoading
                ? 'Sending...'
                : 'Ready',
            isError: false,
            isDone: false,
            isWorking: _isChatLoading,
            isThinking: false,
            isDeploying: false,
          ),
        ),
        if (_showMobileChat)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMobileChat = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {},
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: ChatBottomSheet(
                          messages: _chatMessages,
                          isLoading: _isChatLoading,
                          isLoadingHistory: _isLoadingHistory,
                          messageStatuses: _messageStatuses,
                          onRetry: _retryMessage,
                          onLoadMore: _loadMoreHistory,
                          hasMoreHistory: _hasMoreHistory,
                          isLoadingMore: _isLoadingMoreHistory,
                          scrollController: _chatScrollController,
                          onSendMessage: _sendChatMessage,
                          onRedeploy: () {
                            SnackBarHelper.showInfo(
                              context,
                              title: 'Redeploy',
                              message: 'Triggering redeploy...',
                            );
                          },
                          onClose: () {
                            setState(() {
                              _showMobileChat = false;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatTabDesktop(BuildContext context) {
    final theme = Theme.of(context);

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
            ),
            Expanded(
              child: IndexedStack(
                index: _currentChatTabIndex,
                children: [
                  _buildChatPreviewTab(),
                  _buildChatCodeTab(),
                  _buildChatEnvTab(),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: () {
              setState(() {
                _showMobileChat = true;
              });
              _initializeChat();
            },
            statusLabel: _isChatLoading
                ? 'Sending...'
                : 'Ready',
            isError: false,
            isDone: false,
            isWorking: _isChatLoading,
            isThinking: false,
            isDeploying: false,
          ),
        ),
        if (_showMobileChat)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMobileChat = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {},
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: DraggableScrollableSheet(
                        initialChildSize: 0.7,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        builder: (context, scrollController) {
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: ChatBottomSheet(
                              messages: _chatMessages,
                              isLoading: _isChatLoading,
                              isLoadingHistory: _isLoadingHistory,
                              messageStatuses: _messageStatuses,
                              onRetry: _retryMessage,
                              onLoadMore: _loadMoreHistory,
                              hasMoreHistory: _hasMoreHistory,
                              isLoadingMore: _isLoadingMoreHistory,
                              scrollController: _chatScrollController,
                              onSendMessage: _sendChatMessage,
                              onRedeploy: () {
                                SnackBarHelper.showInfo(
                                  context,
                                  title: 'Redeploy',
                                  message: 'Triggering redeploy...',
                                );
                              },
                              onClose: () {
                                setState(() {
                                  _showMobileChat = false;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatPreviewTabMobile() {
    final previewUrl = widget.previewUrl;
    if (previewUrl == null || previewUrl.isEmpty) {
      return const NoPreviewAvailableView();
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: ProjectChatWebView(url: previewUrl),
          ),
        ),
      ],
    );
  }

  Widget _buildChatPreviewTab() {
    final previewUrl = widget.previewUrl;
    if (previewUrl == null || previewUrl.isEmpty) {
      return const NoPreviewAvailableView();
    }

    return Column(
      children: [
        ProjectChatPreviewHeader(
          previewUrl: previewUrl,
          onRefreshPreview: _handleRefreshPreview,
          onOpenInNewTab: _handleOpenInNewTab,
        ),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: ProjectChatWebView(url: previewUrl),
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

  Widget _buildChatEnvTab() {
    if (_envVars.isEmpty && !_isLoadingEnvVars) {
      _loadEnvVars();
    }

    return ProjectChatEnvTab(
      envVars: _envVars,
      isLoading: _isLoadingEnvVars,
      onAskAboutEnvVar: (envVar) {
        final question =
            'Can you explain what the environment variable "${envVar.key}" is for and how it should be configured?';
        _sendFirstMessage(question);
        _currentChatTabIndex = 0;
      },
    );
  }

  void _handleRefreshPreview() {
    SnackBarHelper.showInfo(
      context,
      title: 'Refresh Preview',
      message: 'Refreshing preview...',
    );
  }

  void _handleOpenInNewTab() {
    final previewUrl = widget.previewUrl;
    if (previewUrl == null || previewUrl.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: 'No Preview URL',
        message: 'Preview URL is not available',
      );
      return;
    }

    final uri = Uri.tryParse(previewUrl);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
