import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analytics.dart';
import '../../models/message.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
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
  final D1vaiService _d1vaiService = D1vaiService();
  final ChatService _chatService = ChatService();

  Map<String, dynamic>? _values;
  Map<String, dynamic>? _activeVisitors;
  Map<String, dynamic>? _pageviews;
  List<dynamic> _topPages = [];
  List<dynamic> _topReferrers = [];
  List<ChartSeries> _trafficSeries = [];
  String? _loadError;

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
    final enabledChanged =
        oldWidget.project.analyticsId != widget.project.analyticsId;
    if (enabledChanged && _hasAnalyticsEnabled) {
      _loadAnalytics();
    }
    if (oldWidget.project.id != widget.project.id) {
      _values = null;
      _activeVisitors = null;
      _pageviews = null;
      _topPages = [];
      _topReferrers = [];
      _trafficSeries = [];
      _loadError = null;
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
      widget.project.analyticsId != null &&
      widget.project.analyticsId!.trim().isNotEmpty;

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final now = DateTime.now();
      final endAt = now.millisecondsSinceEpoch;
      final startAt = endAt - _timeRange.duration.inMilliseconds;
      final unit = _timeRange.duration.inHours <= 24 ? 'hour' : 'day';
      const timezone = 'UTC';

      final results = await Future.wait([
        _d1vaiService.getUmamiWebsiteValues(
          widget.project.id,
          startAt: startAt,
          endAt: endAt,
        ),
        _d1vaiService.getUmamiActiveVisitors(widget.project.id),
        _d1vaiService.getUmamiPageviews(widget.project.id, {
          'unit': unit,
          'timezone': timezone,
          'startAt': startAt,
          'endAt': endAt,
        }),
        _d1vaiService.getUmamiMetrics(widget.project.id, {
          'type': 'url',
          'startAt': startAt,
          'endAt': endAt,
          'limit': 5,
        }),
        _d1vaiService.getUmamiMetrics(widget.project.id, {
          'type': 'referrer',
          'startAt': startAt,
          'endAt': endAt,
          'limit': 5,
        }),
      ]);

      if (!mounted) return;

      final values = results[0] as Map<String, dynamic>;
      final active = results[1] as Map<String, dynamic>;
      final pageviews = results[2] as Map<String, dynamic>;
      final topPages = results[3] as List<dynamic>;
      final topReferrers = results[4] as List<dynamic>;

      setState(() {
        _values = values;
        _activeVisitors = active;
        _pageviews = pageviews;
        _topPages = topPages;
        _topReferrers = topReferrers;
        _trafficSeries = _createTrafficSeries(pageviews);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      setState(() {
        _isLoading = false;
        _loadError = msg;
      });
      debugPrint('Error loading analytics: $e');
      final authExpired = isAuthExpiredText(msg);
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
      );
    }
  }

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
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
          final capped = nextText.length > 120000
              ? nextText.substring(nextText.length - 120000)
              : nextText;
          final nextContents = contents.toList();
          nextContents[nextContents.length - 1] = TextMessageContent(
            text: capped,
          );
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
        if (_installMessages.isNotEmpty &&
            _installMessages.last.role != 'user') {
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
      _installMessages = MessageParser.mergeToolResultsIntoPrevToolCalls(
        _installMessages,
      );
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
      final tracking = await service.getProjectAnalyticsTrackingCode(
        widget.project.id,
      );

      final data = tracking['data'] is Map<String, dynamic>
          ? tracking['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final initData = initRes['data'] is Map<String, dynamic>
          ? initRes['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final websiteId =
          data['website_id']?.toString() ??
          initData['analytics_id']?.toString();
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
                final ok =
                    (code == 0 || code == '0') &&
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
                    _installError =
                        'Analytics install did not complete successfully.';
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
            _installError = humanizeError(e);
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
      final msg = humanizeError(e);
      setState(() {
        _installTyping = false;
        _installing = false;
        _installError = msg;
      });
      final authExpired = isAuthExpiredText(msg);
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
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

  List<ChartSeries> _createTrafficSeries(Map<String, dynamic> data) {
    List<MetricDataPoint> parseSeries(dynamic raw) {
      if (raw is! List) return const [];
      final out = <MetricDataPoint>[];
      for (final it in raw) {
        if (it is! Map) continue;
        final x = it['x'] ?? it['t'];
        final y = it['y'] ?? it['value'];
        DateTime? ts;
        if (x is int) {
          ts = DateTime.fromMillisecondsSinceEpoch(x);
        } else if (x is num) {
          ts = DateTime.fromMillisecondsSinceEpoch(x.toInt());
        } else if (x is String && x.trim().isNotEmpty) {
          ts = DateTime.tryParse(x.trim());
        }
        final v = y is num ? y.toDouble() : double.tryParse('$y') ?? 0;
        out.add(
          MetricDataPoint(
            timestamp: ts ?? DateTime.now(),
            value: v,
            label: x?.toString(),
          ),
        );
      }
      return out;
    }

    final pageviews = parseSeries(data['pageviews']);
    final sessions = parseSeries(data['sessions']);

    final series = <ChartSeries>[];
    if (pageviews.isNotEmpty) {
      series.add(
        ChartSeries(name: 'Pageviews', data: pageviews, color: Colors.blue),
      );
    }
    if (sessions.isNotEmpty) {
      series.add(
        ChartSeries(name: 'Sessions', data: sessions, color: Colors.green),
      );
    }
    return series;
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

    final hasAnyData =
        _values != null ||
        _pageviews != null ||
        _activeVisitors != null ||
        _topPages.isNotEmpty ||
        _topReferrers.isNotEmpty;

    if (_isLoading && !hasAnyData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasAnyData) {
      final msg = (_loadError ?? '').trim().isNotEmpty
          ? _loadError!.trim()
          : 'Analytics data will appear once your project is live and receiving traffic.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                msg,
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalytics,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodCard(),
            const SizedBox(height: 16),
            _buildKeyMetricsRow(),
            const SizedBox(height: 16),
            if (_trafficSeries.isNotEmpty) ...[
              RealtimeChart(
                title: 'Traffic Overview',
                series: _trafficSeries,
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
            _buildTopListsCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatTimeRangeLabel() {
    final now = DateTime.now();
    final start = now.subtract(_timeRange.duration);
    return '${start.toLocal()} → ${now.toLocal()}';
  }

  int _activeNow() {
    final raw = _activeVisitors;
    if (raw == null) return 0;
    return _asInt(raw['x'] ?? raw['visitors'] ?? raw['count'] ?? raw['active']);
  }

  List<dynamic> _normalizeMetricList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return raw['data'] as List;
    }
    return const [];
  }

  Widget _buildPeriodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: Colors.deepPurple,
              size: 24,
            ),
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
                    _formatTimeRangeLabel(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsRow() {
    final values = _values ?? const <String, dynamic>{};
    final pageviews = _asInt(values['pageviews'] ?? values['views']);
    final visitors = _asInt(values['visitors'] ?? values['uniqueVisitors']);
    final sessions = _asInt(values['sessions'] ?? values['visits']);
    final activeNow = _activeNow();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Pageviews',
                value: pageviews.toString(),
                icon: Icons.visibility,
                color: Colors.blue,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze my pageviews trend and suggest ways to increase traffic and retention?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Visitors',
                value: visitors.toString(),
                icon: Icons.people,
                color: Colors.purple,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze my visitor acquisition and suggest improvements (SEO, referrers, landing pages)?',
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
                title: 'Sessions',
                value: sessions.toString(),
                icon: Icons.timeline,
                color: Colors.teal,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you analyze my sessions and suggest how to increase engagement and session duration?',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: 'Active Now',
                value: activeNow.toString(),
                icon: Icons.bolt,
                color: Colors.indigo,
                onTap: () {
                  widget.onAskAi?.call(
                    'Can you help me interpret my real-time active users and recommend actions to improve conversion?',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final values = _values ?? const <String, dynamic>{};
    final bounces = _asInt(values['bounces']);
    final totalTimeSeconds = _asInt(values['totaltime'] ?? values['totalTime']);
    final visits = _asInt(values['visits']);

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
                        'Bounces',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bounces.toString(),
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
                        'Total time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalTimeSeconds > 0
                            ? '${(totalTimeSeconds / 60).toStringAsFixed(1)} min'
                            : (visits > 0 ? '$visits visits' : '—'),
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

  Widget _buildTopListsCard() {
    final pages = _normalizeMetricList(_topPages).take(5).toList();
    final refs = _normalizeMetricList(_topReferrers).take(5).toList();

    String itemLabel(dynamic it) {
      if (it is Map)
        return (it['x'] ?? it['name'] ?? it['label'] ?? '—').toString();
      return it.toString();
    }

    String itemValue(dynamic it) {
      if (it is Map) return _asInt(it['y'] ?? it['value']).toString();
      return '';
    }

    Widget buildList(String title, List<dynamic> items) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'No data',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              ...items.map((it) {
                final label = itemLabel(it);
                final val = itemValue(it);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        val,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Traffic Sources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildList('Top pages', pages),
                const SizedBox(width: 16),
                buildList('Top referrers', refs),
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
              leading: const Icon(Icons.code, color: Colors.deepPurple),
              title: const Text('Copy Tracking Code'),
              subtitle: const Text('Copy Umami script snippet'),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: _copyTrackingCode,
            ),
            const Divider(),
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

  Future<void> _copyTrackingCode() async {
    try {
      final tracking = await _d1vaiService.getProjectAnalyticsTrackingCode(
        widget.project.id,
      );
      final code = (tracking['tracking_code'] ?? '').toString();
      if (code.trim().isEmpty) {
        throw Exception('Tracking code is empty');
      }
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Tracking code copied',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Copy failed',
        message: humanizeError(e),
      );
    }
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  const _EnableAnalyticsCard({required this.enabling, required this.onEnable});

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
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
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
                      label: Text(
                        enabling ? 'Initializing...' : 'Enable Analytics',
                      ),
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
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              installing
                                  ? 'Installing Analytics…'
                                  : 'Analytics Installer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              installing
                                  ? 'We are initializing Umami and inserting the tracking script via a chat session.'
                                  : 'Review the session output or retry the install.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
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
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
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
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.25,
                        ),
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
                          child: Text(
                            installing ? 'Running…' : 'Retry Install',
                          ),
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
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MessageList(messages: messages, showTimestamps: false),
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
