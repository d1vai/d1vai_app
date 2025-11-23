import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/project.dart';
import '../models/deployment.dart';
import '../models/database_table.dart';
import '../models/analytics.dart';
import '../models/env_var.dart';
import '../models/payment.dart';
import '../models/message.dart';
import '../services/d1vai_service.dart';
import '../services/chat_service.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/app_preview.dart';
import '../widgets/table_detail_dialog.dart';
import '../widgets/chat/message_list.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/quick_actions.dart';
import '../widgets/chat/floating_chat_button.dart';
import '../widgets/chat/chat_bottom_sheet.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProject? _project;
  bool _isLoading = true;
  String? _error;
  List<DeploymentHistory> _deployments = [];
  bool _isLoadingDeployments = false;
  List<DatabaseTable> _databaseTables = [];
  bool _isLoadingDatabase = false;
  AnalyticsSummary? _analyticsSummary;
  bool _isLoadingAnalytics = false;
  List<EnvVar> _envVars = [];
  bool _isLoadingEnvVars = false;
  PayMetrics? _payMetrics;
  List<PayProduct> _payProducts = [];
  List<PaymentTransaction> _paymentTransactions = [];
  bool _isLoadingPayment = false;

  // Chat related state
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _chatMessages = [];
  bool _isChatLoading = false;
  bool _isTyping = false;
  String? _currentSessionId;
  String? _websocketUrl;
  StreamSubscription? _webSocketSubscription;
  final ScrollController _chatScrollController = ScrollController();

  // Mobile chat bottom sheet state
  bool _showMobileChat = false;

  final List<TabItem> _tabs = [
    TabItem('Overview', Icons.dashboard, 'overview'),
    TabItem('Chat', Icons.chat, 'chat'),
    TabItem('Database', Icons.storage, 'database'),
    TabItem('API', Icons.api, 'api'),
    TabItem('GitHub', Icons.code, 'github'),
    TabItem('Payment', Icons.payment, 'payment'),
    TabItem('Deploy', Icons.cloud_upload, 'deploy'),
    TabItem('Analytics', Icons.analytics, 'analytics'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showLoginRequiredDialog();
      } else {
        _loadProject();
      }
    });
  }

  /// 加载项目详情
  Future<void> _loadProject() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);

      // 首先尝试从缓存获取
      var project = projectProvider.getProjectById(widget.projectId);

      if (project == null) {
        // 如果缓存中没有，从 API 获取
        final d1vaiService = D1vaiService();
        project = await d1vaiService.getUserProjectById(widget.projectId);
      }

      setState(() {
        _project = project;
        _isLoading = false;
      });

      // Load deployments after project is loaded
      _loadDeployments();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 打开 URL
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Cannot Open URL',
        message: 'Could not open $url',
      );
    }
  }

  /// 加载部署历史
  Future<void> _loadDeployments() async {
    if (_project == null) return;

    setState(() {
      _isLoadingDeployments = true;
    });

    try {
      final d1vaiService = D1vaiService();
      final deployments = await d1vaiService.getProjectDeploymentHistory(
        _project!.id,
        limit: 5,
      );

      setState(() {
        _deployments = deployments;
        _isLoadingDeployments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDeployments = false;
      });
    }
  }

  /// 加载数据库表格列表
  Future<void> _loadDatabaseTables() async {
    if (_project == null) return;

    setState(() {
      _isLoadingDatabase = true;
    });

    try {
      final d1vaiService = D1vaiService();
      final schemaData = await d1vaiService.getProjectDbSchema(
        _project!.id,
        withRowCounts: true,
        includeViews: true,
      );

      final List<DatabaseTable> tables = [];
      if (schemaData['schemas'] != null) {
        for (var schema in schemaData['schemas']) {
          if (schema['tables'] != null) {
            for (var table in schema['tables']) {
              tables.add(DatabaseTable.fromJson(table));
            }
          }
        }
      }

      setState(() {
        _databaseTables = tables;
        _isLoadingDatabase = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDatabase = false;
      });
    }
  }

  /// 加载分析数据
  Future<void> _loadAnalytics() async {
    if (_project == null) return;

    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      final d1vaiService = D1vaiService();
      final analyticsData = await d1vaiService.getProjectAnalyticsSummary(
        _project!.id,
        startDate: DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        endDate: DateTime.now().toIso8601String(),
      );

      setState(() {
        _analyticsSummary = AnalyticsSummary.fromJson(analyticsData);
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAnalytics = false;
      });
    }
  }

  /// 加载环境变量
  Future<void> _loadEnvVars() async {
    if (_project == null) return;

    setState(() {
      _isLoadingEnvVars = true;
    });

    try {
      final d1vaiService = D1vaiService();
      final envVarsData = await d1vaiService.listEnvVars(
        _project!.id,
        showValues: false,
      );

      final List<EnvVar> envVars = List<EnvVar>.from(
        envVarsData.map((item) => EnvVar.fromJson(item)),
      );

      setState(() {
        _envVars = envVars;
        _isLoadingEnvVars = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingEnvVars = false;
      });
    }
  }

  /// 加载支付数据
  Future<void> _loadPaymentData() async {
    if (_project == null) return;

    setState(() {
      _isLoadingPayment = true;
    });

    try {
      final d1vaiService = D1vaiService();

      // 并行加载支付数据
      final results = await Future.wait([
        d1vaiService.getPayDashboardMetrics(_project!.id, days: '30'),
        d1vaiService.getPayProducts(_project!.id),
        d1vaiService.getPayTransactions(_project!.id, status: 'success'),
      ]);

      final metricsData = results[0] as Map<String, dynamic>;
      final productsData = results[1] as List<dynamic>;
      final transactionsData = results[2] as List<dynamic>;

      final payMetrics = PayMetrics.fromJson(metricsData);
      final payProducts = productsData
          .map((item) => PayProduct.fromJson(item))
          .toList();
      final paymentTransactions = transactionsData
          .map((item) => PaymentTransaction.fromJson(item))
          .toList();

      setState(() {
        _payMetrics = payMetrics;
        _payProducts = payProducts;
        _paymentTransactions = paymentTransactions;
        _isLoadingPayment = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPayment = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _webSocketSubscription?.cancel();
    _chatScrollController.dispose();
    super.dispose();
  }

  /// 显示登录提示对话框
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(),
    );
  }

  /// 格式化时间
  String _formatTimeAgo(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  /// 获取部署标签（显示域名或端口）
  String _getDeploymentLabel(String? url) {
    if (url == null || url.isEmpty) {
      return 'Configure later';
    }
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  /// 打开预览 URL
  Future<void> _openPreviewUrl(String url) async {
    if (!mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (mounted && canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Could not open preview URL',
      );
    }
  }

  /// 打开 GitHub 仓库
  Future<void> _openGitHubRepo(String repoName) async {
    if (!mounted) return;

    final githubUrl = 'https://github.com/d1vai/$repoName';
    final uri = Uri.tryParse(githubUrl);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (mounted && canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Could not open GitHub repository',
      );
    }
  }

  /// 复制项目
  void _duplicateProject() {
    final projectName = _project?.projectName ?? 'Current Project';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duplicate Project'),
          content: Text('Are you sure you want to duplicate "$projectName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performDuplicate();
              },
              child: const Text('Duplicate'),
            ),
          ],
        );
      },
    );
  }

  /// 执行复制操作
  Future<void> _performDuplicate() async {
    if (!mounted) return;

    // 显示加载状态
    SnackBarHelper.showInfo(
      context,
      title: 'Duplicating',
      message: 'Creating a copy of the project...',
    );

    // 模拟复制操作
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    SnackBarHelper.showSuccess(
      context,
      title: 'Success',
      message: 'Project duplicated successfully',
    );
  }

  /// 归档项目
  void _archiveProject() {
    final projectName = _project?.projectName ?? 'Current Project';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Archive Project'),
          content: Text('Are you sure you want to archive "$projectName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performArchive();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
              ),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );
  }

  /// 执行归档操作
  Future<void> _performArchive() async {
    if (!mounted) return;

    // 显示加载状态
    SnackBarHelper.showInfo(
      context,
      title: 'Archiving',
      message: 'Archiving the project...',
    );

    // 模拟归档操作
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    SnackBarHelper.showSuccess(
      context,
      title: 'Success',
      message: 'Project archived successfully',
    );
  }

  /// 显示编辑项目对话框
  void _showEditProjectDialog() {
    final projectNameController = TextEditingController(
      text: _project?.projectName ?? '',
    );
    final projectDescriptionController = TextEditingController(
      text: _project?.projectDescription ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: projectNameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: projectDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performEditProject(
                  projectNameController.text,
                  projectDescriptionController.text,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// 初始化聊天会话
  void _initializeChat() async {
    if (_currentSessionId != null) return; // 已经初始化过了

    try {
      // First, load chat history
      await _loadChatHistory();

      // Then create a new session for the WebSocket connection
      final response = await _chatService.executeSession(
        projectId: widget.projectId,
        prompt: '',
        sessionType: 'new',
      );

      if (!mounted) return;

      setState(() {
        _currentSessionId = response.sessionId;
        _websocketUrl = response.websocketUrl;
      });

      _connectWebSocket();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to initialize chat: $e',
      );
    }
  }

  /// 加载聊天历史
  Future<void> _loadChatHistory() async {
    try {
      final history = await _chatService.getChatHistory(
        projectId: widget.projectId,
        limit: 50,
        messageType: 'all', // Load all message types
      );

      if (!mounted) return;

      // Convert ChatHistoryEntry to ChatMessage
      final messages = <ChatMessage>[];
      for (final entry in history) {
        final message = _convertHistoryEntryToChatMessage(entry);
        if (message != null) {
          messages.add(message);
        }
      }

      setState(() {
        _chatMessages.clear();
        _chatMessages.addAll(messages);
      });
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
      // Don't show error to user, just log it
    }
  }

  /// 将 ChatHistoryEntry 转换为 ChatMessage
  ChatMessage? _convertHistoryEntryToChatMessage(ChatHistoryEntry entry) {
    try {
      final role = entry.direction == 'user' ? 'user' : 'assistant';
      final contents = <MessageContent>[];

      // Parse the payload to extract message content
      if (entry.payload != null) {
        final payload = entry.payload;

        // Handle prompt messages
        if (entry.messageType == 'prompt' && payload['prompt'] != null) {
          contents.add(TextMessageContent(text: payload['prompt'] as String));
        }
        // Handle result messages
        else if (entry.messageType == 'result') {
          if (payload['text'] != null) {
            contents.add(TextMessageContent(text: payload['text'] as String));
          } else if (payload['content'] != null) {
            contents.add(TextMessageContent(text: payload['content'] as String));
          } else if (payload['result'] != null) {
            contents.add(ResultMessageContent(payload: payload['result']));
          }
        }
        // Handle git commit messages
        else if (entry.messageType == 'git_commit') {
          contents.add(GitCommitMessageContent(
            projectId: payload['projectId'] as String?,
            message: payload['message'] as String? ?? '',
            files: (payload['files'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(),
          ));
        }
        // Handle completion messages
        else if (entry.messageType == 'complete') {
          final success = payload['success'] as bool? ?? false;
          final message = payload['message'] as String? ?? '';
          contents.add(CompletionMessageContent(
            message: message,
            success: success,
            details: payload['details'] as String?,
          ));
        }
        // Handle error messages
        else if (entry.messageType == 'error') {
          contents.add(ErrorMessageContent(
            message: payload['message'] as String? ?? 'Unknown error',
            code: payload['code'] as String?,
            details: payload['details'],
          ));
        }
        // Fallback for unknown types
        else {
          final text = entry.messageText ??
              (payload['text'] as String?) ??
              (payload['content'] as String?) ??
              json.encode(payload);
          contents.add(TextMessageContent(text: text));
        }
      }
      // Fallback if no payload
      else if (entry.messageText != null) {
        contents.add(TextMessageContent(text: entry.messageText!));
      } else {
        return null; // Skip entries with no content
      }

      return ChatMessage(
        id: entry.id.toString(),
        role: role,
        createdAt: entry.createdAt,
        contents: contents,
      );
    } catch (e) {
      debugPrint('Failed to convert history entry: $e');
      return null;
    }
  }

  /// 连接 WebSocket
  void _connectWebSocket() async {
    if (_websocketUrl == null) return;

    try {
      final webSocket = await _chatService.connectWebSocket(
        websocketUrl: _websocketUrl!,
      );

      if (!mounted) {
        webSocket.close();
        return;
      }

      _webSocketSubscription = webSocket.listen(
        (data) {
          final message = _chatService.parseWebSocketMessage(data);
          if (message != null) {
            setState(() {
              _chatMessages.add(message);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isTyping = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isTyping = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to connect: $e',
      );
    }
  }

  /// 发送聊天消息
  void _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    setState(() {
      _isChatLoading = true;
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
      _isChatLoading = false;
    });

    _scrollToBottom();

    try {
      // 如果会话不存在，创建新会话；如果存在，继续会话
      if (_currentSessionId == null) {
        // 创建新会话
        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'new',
        );

        if (!mounted) return;

        setState(() {
          _currentSessionId = response.sessionId;
          _websocketUrl = response.websocketUrl;
        });

        _connectWebSocket();
      } else {
        // 继续现有会话
        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'continue',
          sessionId: _currentSessionId!,
        );

        // The response will come through the WebSocket connection
        // We don't need to parse it here as the WebSocket listener will handle it
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send message: $e',
      );
    }
  }

  /// 发送第一条消息（如果会话不存在则创建会话）
  void _sendFirstMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    setState(() {
      _isChatLoading = true;
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      createdAt: DateTime.now(),
      contents: [TextMessageContent(text: text)],
    );

    setState(() {
      _chatMessages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // 如果会话不存在，创建新会话并发送消息
      if (_currentSessionId == null) {
        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'new',
        );

        if (!mounted) return;

        setState(() {
          _currentSessionId = response.sessionId;
          _websocketUrl = response.websocketUrl;
          _isChatLoading = false;
        });

        _connectWebSocket();
      } else {
        // 会话已存在，继续会话
        setState(() {
          _isChatLoading = false;
        });

        final response = await _chatService.executeSession(
          projectId: widget.projectId,
          prompt: text,
          sessionType: 'continue',
          sessionId: _currentSessionId!,
        );

        // The response will come through the WebSocket connection
        // We don't need to parse it here as the WebSocket listener will handle it
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isChatLoading = false;
      });
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to send message: $e',
      );
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 向 AI 询问代码相关问题
  void _askAiAboutCode(String question) {
    _sendFirstMessage(question);
  }

  /// 向 AI 询问环境变量相关问题
  void _askAiAboutEnv(String key, String? value) {
    // 构建关于环境变量的智能问题
    final question = 'Can you explain what the environment variable "$key" is for and how it should be configured?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问数据库表相关问题
  void _askAiAboutDatabase(DatabaseTable table) {
    // 构建关于数据库表的智能问题
    final question = 'Can you analyze the database table "${table.displayName}" and explain its purpose, structure, and any suggestions for optimization or best practices?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问支付产品相关问题
  void _askAiAboutPaymentProduct(PayProduct product) {
    // 构建关于支付产品的智能问题
    final question = 'Can you analyze the payment product "${product.name}" and provide suggestions on pricing strategy, configuration, or marketing improvements?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问部署相关问题
  void _askAiAboutDeployment(String environment) {
    // 构建关于部署的智能问题
    final question = 'Can you provide insights and recommendations about the $environment deployment, including performance optimization, troubleshooting, and best practices?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问分析仪表板相关问题
  void _askAiAboutAnalyticsDashboard() {
    // 构建关于分析仪表板的智能问题
    final question = 'Can you help me understand my analytics data and suggest ways to improve user engagement, performance, and overall metrics?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问自定义事件相关问题
  void _askAiAboutCustomEvents() {
    // 构建关于自定义事件的智能问题
    final question = 'Can you guide me on setting up custom event tracking for my project? What are the most important events I should track to improve my product?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问指标相关问题
  void _askAiAboutMetric(String metricName) {
    // 构建关于指标的智能问题
    final question = 'Can you analyze the "$metricName" metric for my project and provide insights on what it means and how to improve it?';
    _sendFirstMessage(question);
  }

  /// 向 AI 询问交易相关问题
  void _askAiAboutTransaction(PaymentTransaction transaction) {
    // 构建关于交易的智能问题
    final question = 'Can you analyze this payment transaction (${transaction.formattedAmount}, ${transaction.statusLabel}) and provide insights about payment patterns or recommendations?';
    _sendFirstMessage(question);
  }

  /// 切换到聊天标签页
  void _switchToChatTab(int subTabIndex) {
    setState(() {
      _currentChatTabIndex = subTabIndex;
    });

    // 如果切换到 Preview Tab，自动滚动到底部显示最新消息
    if (subTabIndex == 0) {
      // 使用 postFrameCallback 确保布局完成后再滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  /// 执行编辑项目操作
  Future<void> _performEditProject(String name, String description) async {
    if (!mounted) return;

    // 显示加载状态
    SnackBarHelper.showInfo(
      context,
      title: 'Saving',
      message: 'Updating project details...',
    );

    // 模拟保存操作
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    SnackBarHelper.showSuccess(
      context,
      title: 'Success',
      message: 'Project updated successfully',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProject,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_project == null) {
      return const Scaffold(
        body: Center(child: Text('Project not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_project!.projectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              SnackBarHelper.showInfo(
                context,
                title: 'Coming Soon',
                message: 'Share feature coming soon',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.icon),
                      const SizedBox(height: 4),
                      Text(tab.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
              .toList(),
          onTap: (index) {
            setState(() {});
            // 当切换到 Database tab 时加载数据
            if (_tabs[index].value == 'database' && _databaseTables.isEmpty) {
              _loadDatabaseTables();
            }
            // 当切换到 Analytics tab 时加载数据
            if (_tabs[index].value == 'analytics' && _analyticsSummary == null) {
              _loadAnalytics();
            }
            // 当切换到 API tab 时加载数据
            if (_tabs[index].value == 'api' && _envVars.isEmpty) {
              _loadEnvVars();
            }
            // 当切换到 Payment tab 时加载数据
            if (_tabs[index].value == 'payment' && _payMetrics == null) {
              _loadPaymentData();
            }
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, _project),
          _buildChatTab(context),
          _buildDatabaseTab(context),
          _buildApiTab(context),
          _buildGithubTab(context),
          _buildPaymentTab(context),
          _buildDeployTab(context),
          _buildAnalyticsTab(context),
        ],
      ),
    );
  }

  /// 构建概览标签
  Widget _buildOverviewTab(BuildContext context, UserProject? project) {
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          project.emoji ?? '🚀',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.projectName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.projectDescription,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusChip(project.status),
                      const SizedBox(width: 8),
                      Text(
                        'Updated ${_formatTimeAgo(project.updatedAt)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App Preview
          AppPreview(
            previewUrl: project.latestPreviewUrl,
            projectName: project.projectName,
          ),
          const SizedBox(height: 16),
          // Project stats card (Created date)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.createdAt.isNotEmpty
                              ? DateFormat('MMM d, yyyy').format(
                                  DateTime.parse(project.createdAt),
                                )
                              : 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            final user = authProvider.user;
                            final email = user?.email ?? 'Unknown';
                            return Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deployment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            if (project.latestPreviewUrl != null && project.latestPreviewUrl!.isNotEmpty) {
                              _openUrl(project.latestPreviewUrl!);
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getDeploymentLabel(project.latestPreviewUrl),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: project.latestPreviewUrl != null && project.latestPreviewUrl!.isNotEmpty
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (project.latestPreviewUrl != null && project.latestPreviewUrl!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Preview URL'),
                  subtitle: Text(project.latestPreviewUrl ?? 'Not available'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    if (project.latestPreviewUrl != null) {
                      _openPreviewUrl(project.latestPreviewUrl!);
                    }
                  },
                ),
                const Divider(height: 1),
ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('GitHub Repository'),
                  subtitle: Text('proj_${project.projectPort}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _openGitHubRepo('proj_${project.projectPort}');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recent Deployments section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Recent deployments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Activity feed',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingDeployments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_deployments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No recent deployments — ship a new build to see activity here.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ..._deployments.map((deployment) {
                      final timestamp = deployment.completedAt ??
                          deployment.startedAt ??
                          deployment.createdAt ??
                          '';
                      Color statusColor;
                      if (deployment.status == 'success') {
                        statusColor = theme.colorScheme.primary;
                      } else if (deployment.status == 'pending') {
                        statusColor = theme.colorScheme.tertiary;
                      } else {
                        statusColor = theme.colorScheme.error;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              deployment.status == 'success'
                                  ? Icons.check_circle
                                  : deployment.status == 'pending'
                                      ? Icons.hourglass_empty
                                      : Icons.error,
                              size: 18,
                              color: statusColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${deployment.environment} • ${deployment.status}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (timestamp.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimeAgo(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Health Metrics card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Health metrics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHealthMetricItem(
                    'Production domain',
                    project.latestProdDeploymentUrl != null && project.latestProdDeploymentUrl!.isNotEmpty
                        ? project.latestProdDeploymentUrl!
                        : (project.vercelProdDomain != null && project.vercelProdDomain!.isNotEmpty
                            ? project.vercelProdDomain!
                            : '—'),
                    project.latestProdDeploymentUrl != null && project.latestProdDeploymentUrl!.isNotEmpty
                        ? 'Primary public endpoint'
                        : 'No domain configured',
                    Icons.language,
                    project.latestProdDeploymentUrl != null && project.latestProdDeploymentUrl!.isNotEmpty,
                  ),
                  const Divider(height: 32),
                  _buildHealthMetricItem(
                    'Analytics status',
                    project.analyticsEnabled == true ? 'Enabled' : 'Disabled',
                    'Traffic instrumentation',
                    Icons.analytics,
                    project.analyticsEnabled == true,
                  ),
                  const Divider(height: 32),
                  _buildHealthMetricItem(
                    'Database',
                    project.projectDatabaseId != null ? 'Enabled' : 'Disabled',
                    'Neon integration',
                    Icons.storage,
                    project.projectDatabaseId != null,
                  ),
                  const Divider(height: 32),
                  _buildHealthMetricItem(
                    'Payments',
                    project.projectPayId != null ? 'Enabled' : 'Disabled',
                    'User-scoped Pay API',
                    Icons.payment,
                    project.projectPayId != null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建健康指标项
  Widget _buildHealthMetricItem(String title, String status, String description, IconData icon, bool isEnabled) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEnabled ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 判断是否为移动端设备
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  /// 构建聊天标签
  Widget _buildChatTab(BuildContext context) {
    final isMobile = _isMobile(context);

    if (isMobile) {
      // 移动端布局：只显示内容，悬浮按钮在底部
      return _buildChatTabMobile(context);
    } else {
      // 桌面端布局：包含聊天消息和输入框
      return _buildChatTabDesktop(context);
    }
  }

  /// 移动端聊天标签布局
  Widget _buildChatTabMobile(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Tab Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildChatTabButton(0, 'Preview', Icons.preview),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChatTabButton(1, 'Code', Icons.code),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChatTabButton(2, 'Env', Icons.settings),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Tab Content
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
        // 悬浮聊天按钮
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingChatButton(
            onPressed: () {
              setState(() {
                _showMobileChat = true;
              });
              // 初始化聊天（如果还未初始化）
              _initializeChat();
            },
            statusLabel: _isChatLoading
                ? 'Sending...'
                : _isTyping
                    ? 'Thinking...'
                    : 'Ready',
            isError: false,
            isDone: false,
            isWorking: _isChatLoading,
            isThinking: _isTyping,
            isDeploying: false,
          ),
        ),
        // 底部抽屉
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
                  onTap: () {}, // 防止事件冒泡
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: ChatBottomSheet(
                          messages: _chatMessages,
                          isTyping: _isTyping,
                          isLoading: _isChatLoading,
                          scrollController: _chatScrollController,
                          onSendMessage: _sendChatMessage,
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

  /// 桌面端聊天标签布局（原始布局）
  Widget _buildChatTabDesktop(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildChatTabButton(0, 'Preview', Icons.preview),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChatTabButton(1, 'Code', Icons.code),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChatTabButton(2, 'Env', Icons.settings),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Tab Content
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
    );
  }

  /// 移动端预览标签（不包含聊天消息和输入框）
  Widget _buildChatPreviewTabMobile() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Preview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Chat with AI to interact with your project',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the chat button below to ask questions about your code, request features, or get help with development.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick Tip',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try asking:\n'
            '• "Add a new page to my app"\n'
            '• "How does this API work?"\n'
            '• "Help me debug this issue"\n'
            '• "Optimize my code"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  int _currentChatTabIndex = 0;

  Widget _buildChatTabButton(int index, String label, IconData icon) {
    final isSelected = _currentChatTabIndex == index;
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentChatTabIndex = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  /// Preview Tab (Chat Preview)
  Widget _buildChatPreviewTab() {
    // Initialize chat when first entering this tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentSessionId == null) {
        _initializeChat();
      }
    });

    return Column(
      children: [
        // Quick actions
        if (_chatMessages.isEmpty)
          QuickActions(
            onSelect: _sendChatMessage,
          ),
        // Messages list
        Expanded(
          child: _chatMessages.isEmpty && !_isTyping
              ? _buildChatEmptyState()
              : MessageList(
                  messages: _chatMessages,
                  isTyping: _isTyping,
                  scrollController: _chatScrollController,
                ),
        ),
        // Message input
        MessageInput(
          onSend: _sendChatMessage,
          isEnabled: !_isChatLoading && _currentSessionId != null,
          hintText: 'Ask about your project...',
        ),
      ],
    );
  }

  /// 构建聊天空状态
  Widget _buildChatEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy,
              size: 80.0,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Chat with AI',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12.0),
            Text(
              'Ask me anything about your project,\ncode, or get help with development',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 24.0),
            FilledButton.icon(
              onPressed: _isChatLoading ? null : () => _sendChatMessage('Hello!'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }

  /// Code Tab
  Widget _buildChatCodeTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('src/'),
              subtitle: const Text('Source files'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _askAiAboutCode('Can you explain the structure and contents of the src/ directory in my project?');
                _switchToChatTab(0); // Switch to Preview tab
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('public/'),
              subtitle: const Text('Static assets'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _askAiAboutCode('Can you help me understand and optimize the files in the public/ directory?');
                _switchToChatTab(0); // Switch to Preview tab
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.description, color: theme.colorScheme.primary),
              title: const Text('package.json'),
              subtitle: const Text('Dependencies'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                _askAiAboutCode('Can you review my package.json and suggest any improvements or additional dependencies?');
                _switchToChatTab(0); // Switch to Preview tab
              },
            ),
          ),
          const SizedBox(height: 16),
          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Click on any file or folder to ask AI for insights, explanations, or suggestions',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Environment Variables Tab
  Widget _buildChatEnvTab() {
    final theme = Theme.of(context);
    if (_isLoadingEnvVars) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_envVars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'No Environment Variables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add environment variables to your project',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _envVars.length,
      itemBuilder: (context, index) {
        final envVar = _envVars[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.key, color: theme.colorScheme.onSecondaryContainer, size: 20),
            ),
            title: Text(envVar.key),
            subtitle: Text(
              (envVar.value == null || envVar.value!.isEmpty)
                  ? '(empty value)'
                  : '************',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              _askAiAboutEnv(envVar.key, envVar.value);
              _switchToChatTab(0); // Switch to Preview tab
            },
            onLongPress: () {
              // Keep the old behavior for long press (show value)
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(envVar.key),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Value:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        (envVar.value == null || envVar.value!.isEmpty)
                            ? '(empty value)'
                            : envVar.value!,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建数据库标签
  Widget _buildDatabaseTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingDatabase) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_databaseTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No database tables',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Database tables will appear here once they are created',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _databaseTables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = _databaseTables[index];
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: table.type == 'view'
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                table.type == 'view' ? Icons.visibility : Icons.table_chart,
                color: table.type == 'view' ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              table.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${table.columns.length} columns • ${table.schema} schema',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (table.rowCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${table.rowCount} rows',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _askAiAboutDatabase(table);
              // 跳转到 Chat Tab
              _tabController.animateTo(1); // Chat tab is at index 1

              // 使用 Future.delayed 确保页面切换后再设置子标签
              Future.delayed(const Duration(milliseconds: 100), () {
                setState(() {
                  _currentChatTabIndex = 0; // Preview sub-tab
                });
              });
            },
            onLongPress: () {
              // Keep the old behavior for long press (show details)
              showDialog(
                context: context,
                builder: (context) => TableDetailDialog(table: table),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建 API 标签
  Widget _buildApiTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment Variables Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Environment Variables',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          SnackBarHelper.showInfo(
                            context,
                            title: 'Add Environment Variable',
                            message: 'Add new environment variable...',
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingEnvVars)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_envVars.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No environment variables — add one to get started.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ..._envVars.map((envVar) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        envVar.key,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (envVar.description != null)
                                        Text(
                                          envVar.description!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (envVar.environment != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: envVar.environmentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: envVar.environmentColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      envVar.environmentLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: envVar.environmentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                PopupMenuButton(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: theme.colorScheme.error),
                                          const SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      SnackBarHelper.showInfo(
                                        context,
                                        title: 'Edit Variable',
                                        message: 'Editing ${envVar.key}...',
                                      );
                                    } else if (value == 'delete') {
                                      SnackBarHelper.showInfo(
                                        context,
                                        title: 'Delete Variable',
                                        message: 'Deleting ${envVar.key}...',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  envVar.isEncrypted ? Icons.lock : Icons.code,
                                  size: 14,
                                  color: envVar.isEncrypted ? theme.colorScheme.tertiary : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  envVar.isEncrypted ? 'Encrypted' : 'Visible',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: envVar.isEncrypted ? theme.colorScheme.tertiary : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // API Tools Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.key, color: theme.colorScheme.tertiary),
                    title: const Text('API Keys'),
                    subtitle: const Text('Manage your API keys'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'API Keys',
                        message: 'API key management coming soon',
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.description, color: theme.colorScheme.secondary),
                    title: const Text('API Documentation'),
                    subtitle: const Text('View API documentation'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'API Documentation',
                        message: 'Documentation coming soon',
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.download, color: theme.colorScheme.primary),
                    title: const Text('Export Variables'),
                    subtitle: const Text('Download all environment variables'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Export',
                        message: 'Exporting environment variables...',
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.upload, color: theme.colorScheme.primary),
                    title: const Text('Import Variables'),
                    subtitle: const Text('Bulk import from .env file'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      SnackBarHelper.showInfo(
                        context,
                        title: 'Import',
                        message: 'Import environment variables...',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 GitHub 标签
  Widget _buildGithubTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GitHub Bot Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy, color: theme.colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GitHub Integration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect your GitHub repository',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_circle, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GitHub Bot Username',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'd1vai-bot',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // GitHub Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.link, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    ),
                    title: const Text('Connect Repository'),
                    subtitle: const Text('Connect an existing GitHub repository'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showConnectRepositoryDialog(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.download, color: theme.colorScheme.primary, size: 20),
                    ),
                    title: const Text('Import from GitHub'),
                    subtitle: const Text('Import a repository as a new project'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showImportFromGithubDialog(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_circle, color: theme.colorScheme.tertiary, size: 20),
                    ),
                    title: const Text('Check Repository Access'),
                    subtitle: const Text('Verify access to a repository'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showCheckAccessDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Connected Repositories (placeholder)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Connected Repositories',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '0',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(Icons.code, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'No repositories connected',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect a GitHub repository to get started',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示连接仓库对话框
  void _showConnectRepositoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
        title: const Text('Connect Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'To connect a GitHub repository:',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
              title: const Text('1. Add d1vai-bot as a collaborator'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
              title: const Text('2. Grant repository access'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
              title: const Text('3. Accept the invitation'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      );
      },
    );
  }

  /// 显示从 GitHub 导入对话框
  void _showImportFromGithubDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from GitHub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import a GitHub repository as a new project:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Select a repository',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Configure import settings',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Create new project',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SnackBarHelper.showInfo(
                context,
                title: 'Import Started',
                message: 'Importing repository...',
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// 显示检查仓库访问权限对话框
  void _showCheckAccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Repository Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify if you have access to a repository:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Repository (owner/repo)',
                hintText: 'e.g., octocat/Hello-World',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SnackBarHelper.showInfo(
                context,
                title: 'Checking Access',
                message: 'Checking repository access...',
              );
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  /// 显示添加支付产品对话框
  void _showAddPayProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCurrency = 'USD';
    bool isActive = true;
    String error = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment Product'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g., Premium Plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your product',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCurrency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Product is available for purchase'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();
                      final priceText = priceController.text.trim();

                      // Validation
                      if (name.isEmpty) {
                        setDialogState(() {
                          error = 'Product name is required';
                        });
                        return;
                      }

                      if (priceText.isEmpty) {
                        setDialogState(() {
                          error = 'Price is required';
                        });
                        return;
                      }

                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        setDialogState(() {
                          error = 'Please enter a valid price';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        error = '';
                      });

                      try {
                        // Simulate API call
                        await Future.delayed(const Duration(seconds: 1));

                        // Create product object
                        final product = PayProduct(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          description: description.isEmpty ? null : description,
                          price: price,
                          currency: selectedCurrency,
                          isActive: isActive,
                          createdAt: DateTime.now().toIso8601String(),
                        );

                        if (!mounted) return;

                        // Add to local list
                        setState(() {
                          _payProducts.add(product);
                        });

                        // Close dialog
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          error = 'Failed to add product: $e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示编辑支付产品对话框
  void _showEditPayProductDialog(BuildContext context, PayProduct product) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(text: product.description ?? '');
    final priceController = TextEditingController(text: product.price.toString());
    String selectedCurrency = product.currency;
    bool isActive = product.isActive;
    String error = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Payment Product'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g., Premium Plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your product',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCurrency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Product is available for purchase'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();
                      final priceText = priceController.text.trim();

                      // Validation
                      if (name.isEmpty) {
                        setDialogState(() {
                          error = 'Product name is required';
                        });
                        return;
                      }

                      if (priceText.isEmpty) {
                        setDialogState(() {
                          error = 'Price is required';
                        });
                        return;
                      }

                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        setDialogState(() {
                          error = 'Please enter a valid price';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        error = '';
                      });

                      try {
                        // Simulate API call
                        await Future.delayed(const Duration(seconds: 1));

                        if (!mounted) return;

                        // Update product in local list
                        setState(() {
                          final index = _payProducts.indexOf(product);
                          if (index != -1) {
                            _payProducts[index] = PayProduct(
                              id: product.id,
                              name: name,
                              description: description.isEmpty ? null : description,
                              price: price,
                              currency: selectedCurrency,
                              isActive: isActive,
                              createdAt: product.createdAt,
                            );
                          }
                        });

                        // Close dialog
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          error = 'Failed to update product: $e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建支付标签
  Widget _buildPaymentTab(BuildContext context) {
    if (_isLoadingPayment) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Overview Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_payMetrics != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPayMetricCard(
                            'Total Revenue',
                            _payMetrics!.formattedRevenue,
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPayMetricCard(
                            'Transactions',
                            _payMetrics!.totalTransactions.toString(),
                            Icons.receipt,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPayMetricCard(
                            'Conversion Rate',
                            _payMetrics!.formattedConversionRate,
                            Icons.trending_up,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPayMetricCard(
                            'Active Customers',
                            _payMetrics!.activeCustomers.toString(),
                            Icons.people,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      'Payment not activated yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Products
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Payment Products',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showAddPayProductDialog(context);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_payProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No payment products yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ..._payProducts.map((product) {
                      return InkWell(
                        onTap: () {
                          _askAiAboutPaymentProduct(product);
                          _tabController.animateTo(1); // Chat tab is at index 1
                          Future.delayed(const Duration(milliseconds: 100), () {
                            setState(() {
                              _currentChatTabIndex = 0; // Preview sub-tab
                            });
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (product.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        product.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                product.formattedPrice,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: product.price > 0
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton(
                                icon: const Icon(Icons.more_vert, size: 20),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'link',
                                    child: Row(
                                      children: [
                                        Icon(Icons.link, size: 18),
                                        SizedBox(width: 8),
                                        Text('Get Link'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditPayProductDialog(context, product);
                                  } else if (value == 'link') {
                                    SnackBarHelper.showInfo(
                                      context,
                                      title: 'Payment Link',
                                      message: 'Getting payment link...',
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Transactions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_paymentTransactions.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_paymentTransactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ..._paymentTransactions.take(5).map((transaction) {
                      return InkWell(
                        onTap: () {
                          _askAiAboutTransaction(transaction);
                          _tabController.animateTo(1); // Chat tab is at index 1
                          Future.delayed(const Duration(milliseconds: 100), () {
                            setState(() {
                              _currentChatTabIndex = 0; // Preview sub-tab
                            });
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                transaction.statusIcon,
                                size: 20,
                                color: transaction.statusColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.productName ?? 'Unknown Product',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      transaction.customerEmail ?? 'Anonymous',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    transaction.formattedAmount,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transaction.statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: transaction.statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建支付指标卡片
  Widget _buildPayMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建部署标签
  Widget _buildDeployTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current deployments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Deployments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Production deployment
                  if (_project?.latestProdDeploymentUrl != null &&
                      _project!.latestProdDeploymentUrl!.isNotEmpty)
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                      ),
                      title: const Text('Production'),
                      subtitle: Text(
                        _getDeploymentLabel(_project!.latestProdDeploymentUrl),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              _openUrl(_project!.latestProdDeploymentUrl!);
                            },
                            child: const Text('Open'),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                      onTap: () {
                        _askAiAboutDeployment('Production');
                        _tabController.animateTo(1); // Chat tab is at index 1
                        Future.delayed(const Duration(milliseconds: 100), () {
                          setState(() {
                            _currentChatTabIndex = 0; // Preview sub-tab
                          });
                        });
                      },
                    )
                  else
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.cancel, color: Colors.grey, size: 24),
                      ),
                      title: const Text('Production'),
                      subtitle: const Text('No production deployment'),
                      onTap: () {},
                    ),
                  // Preview deployment
                  if (_project?.latestPreviewUrl != null &&
                      _project!.latestPreviewUrl!.isNotEmpty) ...[
                    const Divider(),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.preview, color: Colors.blue, size: 24),
                      ),
                      title: const Text('Preview'),
                      subtitle: Text(
                        _getDeploymentLabel(_project!.latestPreviewUrl),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              _openUrl(_project!.latestPreviewUrl!);
                            },
                            child: const Text('Open'),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                      onTap: () {
                        _askAiAboutDeployment('Preview');
                        _tabController.animateTo(1); // Chat tab is at index 1
                        Future.delayed(const Duration(milliseconds: 100), () {
                          setState(() {
                            _currentChatTabIndex = 0; // Preview sub-tab
                          });
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Deployment history
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Deployment History',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_deployments.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingDeployments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_deployments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No deployments yet — deploy your project to see history here.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    ..._deployments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final deployment = entry.value;
                      final isLast = index == _deployments.length - 1;

                      return InkWell(
                        onTap: () {
                          _askAiAboutDeployment(deployment.environment);
                          _tabController.animateTo(1); // Chat tab is at index 1
                          Future.delayed(const Duration(milliseconds: 100), () {
                            setState(() {
                              _currentChatTabIndex = 0; // Preview sub-tab
                            });
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: isLast ? const EdgeInsets.only(bottom: 0) : const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                              children: [
                                Icon(
                                  deployment.status == 'success'
                                      ? Icons.check_circle
                                      : deployment.status == 'pending'
                                          ? Icons.hourglass_empty
                                          : Icons.error,
                                  size: 18,
                                  color: deployment.status == 'success'
                                      ? Colors.green
                                      : deployment.status == 'pending'
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${deployment.environment} deployment',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimeAgo(
                                          deployment.completedAt ??
                                              deployment.startedAt ??
                                              deployment.createdAt ??
                                              '',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    SnackBarHelper.showInfo(
                                      context,
                                      title: 'Deployment Logs',
                                      message: 'Viewing logs for ${deployment.environment} deployment...',
                                    );
                                  },
                                  icon: const Icon(Icons.description, size: 16),
                                  label: const Text('Logs', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            if (deployment.url != null && deployment.url!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getDeploymentLabel(deployment.url),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分析标签
  Widget _buildAnalyticsTab(BuildContext context) {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analyticsSummary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No analytics data',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics data will appear here once your project is live',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final analytics = _analyticsSummary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.deepPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Period: ${analytics.period}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${DateFormat('MMM d, yyyy').format(analytics.startDate)} - ${DateFormat('MMM d, yyyy').format(analytics.endDate)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key metrics
          const Text(
            'Key Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Users',
                  analytics.totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                  onTap: () {
                    _askAiAboutMetric('Total Users');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Active Users',
                  analytics.activeUsers.toString(),
                  Icons.person,
                  Colors.green,
                  onTap: () {
                    _askAiAboutMetric('Active Users');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Requests',
                  analytics.totalRequests.toString(),
                  Icons.http,
                  Colors.orange,
                  onTap: () {
                    _askAiAboutMetric('Total Requests');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Avg Response',
                  '${analytics.averageResponseTime.toStringAsFixed(0)}ms',
                  Icons.speed,
                  Colors.purple,
                  onTap: () {
                    _askAiAboutMetric('Average Response Time');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Uptime',
                  '${(analytics.uptime * 100).toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.teal,
                  onTap: () {
                    _askAiAboutMetric('Uptime');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Success Rate',
                  '${((analytics.successfulRequests / analytics.totalRequests) * 100).toStringAsFixed(1)}%',
                  Icons.thumb_up,
                  Colors.indigo,
                  onTap: () {
                    _askAiAboutMetric('Success Rate');
                    _tabController.animateTo(1); // Chat tab is at index 1
                    Future.delayed(const Duration(milliseconds: 100), () {
                      setState(() {
                        _currentChatTabIndex = 0; // Preview sub-tab
                      });
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.blue),
                    title: const Text('View Detailed Dashboard'),
                    subtitle: const Text('See comprehensive analytics'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _askAiAboutAnalyticsDashboard();
                      _tabController.animateTo(1); // Chat tab is at index 1
                      Future.delayed(const Duration(milliseconds: 100), () {
                        setState(() {
                          _currentChatTabIndex = 0; // Preview sub-tab
                        });
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.track_changes, color: Colors.orange),
                    title: const Text('Track Custom Events'),
                    subtitle: const Text('Add custom tracking'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _askAiAboutCustomEvents();
                      _tabController.animateTo(1); // Chat tab is at index 1
                      Future.delayed(const Duration(milliseconds: 100), () {
                        setState(() {
                          _currentChatTabIndex = 0; // Preview sub-tab
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建指标卡片
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final cardWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    // If onTap is provided, wrap with InkWell for touch feedback
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  /// 构建状态芯片
  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'archived':
        color = Colors.orange;
        label = 'Archived';
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 显示选项菜单
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Project'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditProjectDialog();
                },
              ),
ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Duplicate Project'),
                onTap: () {
                  Navigator.pop(context);
                  _duplicateProject();
                },
              ),
ListTile(
                leading: Icon(Icons.archive, color: Colors.orange),
                title: const Text('Archive Project'),
                onTap: () {
                  Navigator.pop(context);
                  _archiveProject();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Project',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: const Text(
            'Are you sure you want to delete this project? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
                SnackBarHelper.showSuccess(
                  context,
                  title: 'Success',
                  message: 'Project deleted',
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

/// Tab 项目
class TabItem {
  final String label;
  final IconData icon;
  final String value;

  TabItem(this.label, this.icon, this.value);
}
