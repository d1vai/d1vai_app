import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';

import '../../models/analytics.dart';
import '../../models/message.dart';
import '../../models/project.dart';
import '../../services/analytics_service.dart';
import '../../services/chat_service.dart';
import '../../services/d1vai_service.dart';
import '../../utils/message_parser.dart';
import '../chat/message_list.dart';
import '../snackbar_helper.dart';
import '../analytics/realtime_chart.dart';

/// 项目详情页 - Analytics Tab
class ProjectAnalyticsTab extends StatefulWidget {
  final UserProject project;
  final void Function(String prompt)? onAskAi;
  final Future<void> Function()? onRefreshProject;

  const ProjectAnalyticsTab({
    super.key,
    required this.project,
    this.onAskAi,
    this.onRefreshProject,
  });

  @override
  State<ProjectAnalyticsTab> createState() => _ProjectAnalyticsTabState();
}

class _ProjectAnalyticsTabState extends State<ProjectAnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final ChatService _chatService = ChatService();
  
  AnalyticsSummary? _summary;
  List<ChartSeries> _chartSeries = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  TimeRange _timeRange = TimeRange.last24Hours;

  bool _installing = false;
  bool _installTyping = false;
  String? _websiteId;
  String? _installError;
  List<ChatMessage> _installMessages = [];
  WebSocket? _installWs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      if (_hasAnalyticsEnabled) {
        _loadAnalytics();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProjectAnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enabledChanged = oldWidget.project.analyticsId != widget.project.analyticsId;
    if (enabledChanged && _hasAnalyticsEnabled) {
      _loadAnalytics();
    }
    if (oldWidget.project.id != widget.project.id) {
      _summary = null;
      _chartSeries = [];
      _installMessages = [];
      _websiteId = null;
      _installError = null;
      _closeInstallerWebSocket();
      if (_hasAnalyticsEnabled) {
        _loadAnalytics();
      }
    }
  }

  @override
  void dispose() {
    _closeInstallerWebSocket();
    super.dispose();
  }

  bool get _hasAnalyticsEnabled =>
      widget.project.analyticsId != null && widget.project.analyticsId!.trim().isNotEmpty;

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load summary and metrics in parallel
      final results = await Future.wait([
        _analyticsService.getAnalyticsSummary(
          projectId: widget.project.id,
          timeRange: _timeRange,
        ),
        _analyticsService.getRealtimeMetrics(
          projectId: widget.project.id,
        ),
      ]);

      if (!mounted) return;

      final summary = results[0] as AnalyticsSummary;
      final metrics = results[1] as List<RealtimeMetric>;

      setState(() {
        _summary = summary;
        _chartSeries = _createChartSeries(metrics);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading analytics: $e');
    }
  }

  String _buildInstallPrompt(String websiteId) {
    return 'Please help me correctly insert the following website analysis script into my project for statistical access data:\n```html\n<script async src="https://analytics-api.d1v.ai/script.js" data-website-id="{YOUR_WEBSITE_ID}"></script>\n```\nPlease automatically select the appropriate insertion location (such as `_document.tsx`\'s <Head>, `root.html`\'s <head>, `app.vue`\'s template part, etc.) according to the architecture used by the project (such as Next.js, Remix, Vue, Nuxt, React, pure HTML, etc.), and insert it directly in the corresponding file. Please replace `{YOUR_WEBSITE_ID}` with the real ID I provided: $websiteId.';
  }

  void _closeInstallerWebSocket() {
    try {
      _installWs?.close();
    } catch (_) {}
    _installWs = null;
  }

  void _appendAssistantDelta(String delta) {
    setState(() {
      if (_installMessages.isNotEmpty && _installMessages.last.role != 'user') {
        final last = _installMessages.last;
        final contents = last.contents;
        if (contents.isNotEmpty && contents.last is TextMessageContent) {
          final prev = contents.last as TextMessageContent;
          final nextText = (prev.text + delta);
          final capped =
              nextText.length > 120000 ? nextText.substring(nextText.length - 120000) : nextText;
          final nextContents = contents.toList();
          nextContents[nextContents.length - 1] = TextMessageContent(text: capped);
          _installMessages[_installMessages.length - 1] = last.copyWith(
            contents: nextContents,
            createdAt: DateTime.now(),
          );
          return;
        }
      }
      _installMessages.add(
        ChatMessage(
          id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: [TextMessageContent(text: delta)],
        ),
      );
    });
  }

  void _handleWsPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    if (type == null) return;

    if (type == 'history' || type == 'history_complete') return;
    if (type == 'proxy_status') return;
    if (type == 'deployment_start' || type == 'deployment_complete') return;

    if (type == 'content_block_delta' || type == 'message_delta') {
      final delta = MessageParser.normalizeOpcodeText(payload);
      if (delta != null && delta.isNotEmpty) {
        _appendAssistantDelta(delta);
      }
      return;
    }

    if (type == 'assistant_message') {
      final contents = MessageParser.createMessageContentsFromPayload(payload);
      if (contents.isEmpty) return;
      setState(() {
        if (_installMessages.isNotEmpty && _installMessages.last.role != 'user') {
          final last = _installMessages.last;
          _installMessages[_installMessages.length - 1] = last.copyWith(
            contents: contents,
            createdAt: DateTime.now(),
          );
        } else {
          _installMessages.add(
            ChatMessage(
              id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              createdAt: DateTime.now(),
              contents: contents,
            ),
          );
        }
      });
      return;
    }

    final contents = MessageParser.createMessageContentsFromPayload(payload);
    if (contents.isEmpty) return;
    setState(() {
      _installMessages.add(
        ChatMessage(
          id: 'ws-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          createdAt: DateTime.now(),
          contents: contents,
        ),
      );
      _installMessages = MessageParser.mergeToolResultsIntoPrevBashTool(_installMessages);
    });
  }

  Future<void> _enableAndInstallAnalytics() async {
    if (_installing) return;

    setState(() {
      _installing = true;
      _installTyping = false;
      _installError = null;
      _installMessages = [];
      _websiteId = null;
    });

    try {
      final service = D1vaiService();
      final initRes = await service.initProjectAnalytics(widget.project.id);
      final tracking = await service.getProjectAnalyticsTrackingCode(widget.project.id);

      final data = tracking['data'] is Map<String, dynamic>
          ? tracking['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final initData = initRes['data'] is Map<String, dynamic>
          ? initRes['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final websiteId =
          data['website_id']?.toString() ?? initData['analytics_id']?.toString();
      if (websiteId == null || websiteId.trim().isEmpty) {
        throw Exception('Missing website ID after initialization');
      }

      final prompt = _buildInstallPrompt(websiteId);
      setState(() {
        _websiteId = websiteId;
        _installMessages.add(
          ChatMessage(
            id: 'user-${DateTime.now().millisecondsSinceEpoch}',
            role: 'user',
            createdAt: DateTime.now(),
            contents: [TextMessageContent(text: prompt)],
          ),
        );
      });

      final exec = await _chatService.executeSession(
        projectId: widget.project.id,
        prompt: prompt,
        sessionType: 'new',
      );

      final wsUrl = await _chatService.buildProjectSessionWebSocketUrl(
        sessionId: exec.sessionId,
      );
      final ws = await _chatService.connectWebSocket(websocketUrl: wsUrl);
      _installWs = ws;

      setState(() {
        _installTyping = true;
      });

      ws.listen(
        (event) async {
          try {
            final text = event is String
                ? event
                : event is List<int>
                    ? utf8.decode(event)
                    : event.toString();
            final decoded = jsonDecode(text);
            if (decoded is Map<String, dynamic>) {
              final type = decoded['type']?.toString();
              if (type == 'complete') {
                final code = decoded['code'];
                final success = decoded['success'];
                final ok = (code == 0 || code == '0') &&
                    (success == true || success == 'true');

                if (!mounted) return;
                setState(() {
                  _installTyping = false;
                  _installing = false;
                });
                _closeInstallerWebSocket();

                if (ok) {
                  SnackBarHelper.showSuccess(
                    context,
                    title: 'Success',
                    message: 'Analytics successfully installed and activated.',
                  );
                  await widget.onRefreshProject?.call();
                  if (!mounted) return;
                  if (_hasAnalyticsEnabled) {
                    _loadAnalytics();
                  }
                } else {
                  setState(() {
                    _installError = 'Analytics install did not complete successfully.';
                  });
                }
                return;
              }

              _handleWsPayload(decoded);
            }
          } catch (_) {}
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _installTyping = false;
            _installing = false;
            _installError = 'WebSocket error: $e';
          });
          _closeInstallerWebSocket();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _installTyping = false;
            _installing = false;
          });
          _closeInstallerWebSocket();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installTyping = false;
        _installing = false;
        _installError = e.toString();
      });
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to enable analytics',
      );
    }
  }

  Future<void> _copyWebsiteId() async {
    final id = _websiteId;
    if (id == null || id.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'Website ID copied',
    );
  }

  List<ChartSeries> _createChartSeries(List<RealtimeMetric> metrics) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return metrics.asMap().entries.map((entry) {
      final index = entry.key;
      final metric = entry.value;
      return ChartSeries(
        name: metric.name,
        data: metric.data,
        color: colors[index % colors.length],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAnalyticsEnabled) {
      if (_installing || _installMessages.isNotEmpty || _installError != null) {
        return _AnalyticsInstallerView(
          installing: _installing,
          isTyping: _installTyping,
          websiteId: _websiteId,
          error: _installError,
          messages: _installMessages,
          onCopyWebsiteId: _copyWebsiteId,
          onRetry: _enableAndInstallAnalytics,
          onReset: () {
            _closeInstallerWebSocket();
            setState(() {
              _installing = false;
              _installTyping = false;
              _installError = null;
              _installMessages = [];
              _websiteId = null;
            });
          },
        );
      }
      return _EnableAnalyticsCard(
        enabling: _installing,
        onEnable: _enableAndInstallAnalytics,
      );
    }

    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No analytics data yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics data will appear once your project is live and receiving traffic',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final analytics = _summary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodCard(analytics),
          const SizedBox(height: 16),
          if (_chartSeries.isNotEmpty) ...[
            RealtimeChart(
              title: 'Performance Overview',
              series: _chartSeries,
              timeRange: _timeRange,
              height: 250,
              showLegend: true,
              onTimeRangeChanged: (range) {
                setState(() {
                  _timeRange = range;
                });
                _loadAnalytics();
              },
            ),
            const SizedBox(height: 16),
          ],
          _buildKeyMetricsRow(analytics),
          const SizedBox(height: 16),
          _buildStatusCard(analytics),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(AnalyticsSummary analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period: ${_timeRange.label}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From ${analytics.startDate.toLocal()} to ${analytics.endDate.toLocal()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsRow(AnalyticsSummary analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Total Requests',
                value: analytics.totalRequests.toString(),
                icon: Icons.swap_vert,
                color: Colors.blue,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Total Requests" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Avg Response',
                value: '${analytics.averageResponseTime.toStringAsFixed(0)}ms',
                icon: Icons.speed,
                color: Colors.purple,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Average Response Time" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Uptime',
                value: '${(analytics.uptime * 100).toStringAsFixed(1)}%',
                icon: Icons.check_circle,
                color: Colors.teal,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Uptime" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Success Rate',
                value:
                    '${((analytics.successfulRequests / analytics.totalRequests) * 100).toStringAsFixed(1)}%',
                icon: Icons.thumb_up,
                color: Colors.indigo,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze the "Success Rate" metric for my project and provide insights on what it means and how to improve it?',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(AnalyticsSummary analytics) {
    final errorRate = analytics.totalRequests == 0
        ? 0.0
        : (analytics.failedRequests / analytics.totalRequests) * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Users',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analytics.activeUsers}/${analytics.totalUsers} active',
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
                      const Text(
                        'Errors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analytics.failedRequests} (${errorRate.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
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
                widget.onAskAi?.call(
                  'Can you help me understand my analytics data and suggest ways to improve user engagement, performance, and overall metrics?',
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.track_changes, color: Colors.orange),
              title: const Text('Track Custom Events'),
              subtitle: const Text('Add custom tracking'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                widget.onAskAi?.call(
                  'Can you guide me on setting up custom event tracking for my project? What are the most important events I should track to improve my product?',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnalyticsMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

class _EnableAnalyticsCard extends StatelessWidget {
  final bool enabling;
  final VoidCallback onEnable;

  const _EnableAnalyticsCard({
    required this.enabling,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.analytics,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enable Analytics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Track your website's visitors, page views, and custom events with Umami Analytics",
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Features included:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.visibility_outlined,
                    text: 'Real-time visitor tracking',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.mouse_outlined,
                    text: 'Page views and events',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.people_outline,
                    text: 'Unique visitors analytics',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.trending_up,
                    text: 'Traffic trends over time',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: enabling ? null : onEnable,
                      icon: enabling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt),
                      label: Text(enabling ? 'Initializing...' : 'Enable Analytics'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsInstallerView extends StatelessWidget {
  final bool installing;
  final bool isTyping;
  final String? websiteId;
  final String? error;
  final List<ChatMessage> messages;
  final Future<void> Function() onCopyWebsiteId;
  final VoidCallback onRetry;
  final VoidCallback onReset;

  const _AnalyticsInstallerView({
    required this.installing,
    required this.isTyping,
    required this.websiteId,
    required this.error,
    required this.messages,
    required this.onCopyWebsiteId,
    required this.onRetry,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.analytics, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              installing ? 'Installing Analytics…' : 'Analytics Installer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              installing
                                  ? 'We are initializing Umami and inserting the tracking script via a chat session.'
                                  : 'Review the session output or retry the install.',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onReset,
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (websiteId != null && websiteId!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Website ID',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  websiteId!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: onCopyWebsiteId,
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (error != null && error!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: installing ? null : onReset,
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: installing ? null : onRetry,
                          child: Text(installing ? 'Running…' : 'Retry Install'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MessageList(
                  messages: messages,
                  showTimestamps: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
