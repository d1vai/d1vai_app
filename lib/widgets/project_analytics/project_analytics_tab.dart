import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../models/analytics.dart';
import '../../models/message.dart';
import '../../models/project.dart';
import '../../services/chat_service.dart';
import '../../services/d1vai_service.dart';
import '../../services/workspace_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../../utils/message_parser.dart';
import '../chat/message_list.dart';
import '../snackbar_helper.dart';
import '../analytics/realtime_chart.dart';
import '../skeletons/analytics_data_skeleton.dart';
import '../skeletons/analytics_events_skeleton.dart';
import '../skeletons/analytics_sessions_skeleton.dart';

/// 项目详情页 - Analytics Tab
enum AnalyticsEnvScope { all, preview, prod }

enum AnalyticsCompareMode { days7, days30 }

String _tr(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context)?.translate(key);
  if (value == null || value == key) return fallback;
  return value;
}

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
  static const Map<String, String> _compareDimToApiType = {
    'pages': 'path',
    'referrers': 'referrer',
    'browsers': 'browser',
    'os': 'os',
    'devices': 'device',
    'screen': 'screen',
    'countries': 'country',
    'regions': 'region',
    'cities': 'city',
    'languages': 'language',
    'events': 'event',
    'query': 'query',
    'tag': 'tag',
    'channel': 'channel',
    'host': 'hostname',
  };

  final D1vaiService _d1vaiService = D1vaiService();
  final ChatService _chatService = ChatService();
  final WorkspaceService _workspaceService = WorkspaceService();

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
  TimeRange _eventsTimeRange = TimeRange.last7Days;
  AnalyticsEnvScope _envScope = AnalyticsEnvScope.all;
  AnalyticsCompareMode _compareMode = AnalyticsCompareMode.days7;
  String _compareDimension = 'pages';
  bool _showPageviewsSeries = true;
  bool _showSessionsSeries = true;

  bool _installing = false;
  bool _installTyping = false;
  String? _websiteId;
  String? _installError;
  List<ChatMessage> _installMessages = [];
  WebSocket? _installWs;
  bool _showInstallerView = false;
  bool _sharingAccess = false;
  int _analyticsTabIndex = 0;
  bool _installSucceeded = false;
  int _autoEnterCountdown = 0;
  Timer? _autoEnterTimer;

  String _t(String key, String fallback) => _tr(context, key, fallback);

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
      _autoEnterTimer?.cancel();
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
      _showInstallerView = false;
      _analyticsTabIndex = 0;
      _eventsTimeRange = TimeRange.last7Days;
      _compareMode = AnalyticsCompareMode.days7;
      _compareDimension = 'pages';
      _installSucceeded = false;
      _autoEnterCountdown = 0;
      _closeInstallerWebSocket();
      if (_hasAnalyticsEnabled) {
        _loadAnalytics();
      }
    }
  }

  @override
  void dispose() {
    _autoEnterTimer?.cancel();
    _closeInstallerWebSocket();
    super.dispose();
  }

  bool get _hasAnalyticsEnabled => widget.project.hasAnalyticsId;

  String? _hostFromUrl(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    if (uri.host.trim().isEmpty) return null;
    return uri.host.trim();
  }

  String? get _previewHost => _hostFromUrl(widget.project.preferredPreviewUrl);
  String? get _prodHost =>
      _hostFromUrl(widget.project.latestProdDeploymentUrl) ??
      (widget.project.vercelProdDomain?.trim().isEmpty ?? true
          ? null
          : widget.project.vercelProdDomain!.trim());

  List<Map<String, dynamic>> _buildEnvFilters() {
    final host = switch (_envScope) {
      AnalyticsEnvScope.preview => _previewHost,
      AnalyticsEnvScope.prod => _prodHost,
      AnalyticsEnvScope.all => null,
    };
    if (host == null || host.trim().isEmpty) return const [];
    // Umami v3 metrics/filter field for host is `hostname`.
    return [
      {'column': 'hostname', 'operator': 'eq', 'value': host.trim()},
    ];
  }

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
        _d1vaiService.getUmamiWebsite(widget.project.id),
        _d1vaiService.getUmamiActiveVisitors(widget.project.id),
        _d1vaiService.getUmamiPageviews(widget.project.id, {
          'unit': unit,
          'timezone': timezone,
          'startAt': startAt,
          'endAt': endAt,
        }, filters: _buildEnvFilters()),
        _d1vaiService.getUmamiMetrics(widget.project.id, {
          'type': 'path',
          'startAt': startAt,
          'endAt': endAt,
          'limit': 5,
        }, filters: _buildEnvFilters()),
        _d1vaiService.getUmamiMetrics(widget.project.id, {
          'type': 'referrer',
          'startAt': startAt,
          'endAt': endAt,
          'limit': 5,
        }, filters: _buildEnvFilters()),
      ]);

      if (!mounted) return;

      final website = results[0] as Map<String, dynamic>;
      final active = results[1] as Map<String, dynamic>;
      final pageviews = results[2] as Map<String, dynamic>;
      final topPages = results[3] as List<dynamic>;
      final topReferrers = results[4] as List<dynamic>;
      final values = _buildOverviewValues(
        website: website,
        pageviews: pageviews,
      );

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
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/analytics/data/${widget.project.id}',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: msg,
      );
    }
  }

  Map<String, dynamic> _buildOverviewValues({
    required Map<String, dynamic> website,
    required Map<String, dynamic> pageviews,
  }) {
    final pageviewsTotal = _sumPoints(pageviews['pageviews']);
    final sessionsTotal = _sumPoints(pageviews['sessions']);
    final visitors = _asInt(
      website['visitors'] ??
          website['uniqueVisitors'] ??
          website['users'] ??
          sessionsTotal,
    );

    return {
      ...website,
      'pageviews': _asInt(website['pageviews'] ?? website['views']) > 0
          ? _asInt(website['pageviews'] ?? website['views'])
          : pageviewsTotal,
      'sessions': _asInt(website['sessions'] ?? website['visits']) > 0
          ? _asInt(website['sessions'] ?? website['visits'])
          : sessionsTotal,
      'visitors': visitors,
      'visits': _asInt(website['visits']) > 0
          ? _asInt(website['visits'])
          : sessionsTotal,
      'bounces': _asInt(website['bounces']),
      'totaltime': _asInt(website['totaltime'] ?? website['totalTime']),
    };
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
    _autoEnterTimer?.cancel();

    setState(() {
      _installing = true;
      _installTyping = false;
      _installError = null;
      _installMessages = [];
      _websiteId = null;
      _showInstallerView = true;
      _installSucceeded = false;
      _autoEnterCountdown = 0;
    });

    try {
      final service = D1vaiService();
      final initRes = await service.initProjectAnalytics(widget.project.id);
      // Keep project snapshot in sync with backend state right after init.
      try {
        await widget.onRefreshProject?.call();
      } catch (_) {}
      final tracking = await service.getProjectAnalyticsTrackingCode(
        widget.project.id,
      );

      final websiteId =
          tracking['website_id']?.toString() ??
          initRes['analytics_id']?.toString();
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

      await _workspaceService.ensureWorkspaceReady();
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
                  _startAutoEnterDataCountdown();
                  SnackBarHelper.showSuccess(
                    context,
                    title: _t('success', 'Success'),
                    message: _t(
                      'project_analytics_install_success',
                      'Analytics successfully installed and activated.',
                    ),
                  );
                  await widget.onRefreshProject?.call();
                  if (!mounted) return;
                  if (_hasAnalyticsEnabled) {
                    _loadAnalytics();
                  }
                } else {
                  setState(() {
                    _installSucceeded = false;
                    _installError = _t(
                      'project_analytics_install_incomplete',
                      'Analytics install did not complete successfully.',
                    );
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
            _installSucceeded = false;
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
        _installSucceeded = false;
        _installError = msg;
      });
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.project.id}/analytics/install',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: msg,
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
      title: _t('copied', 'Copied'),
      message: _t('project_analytics_website_id_copied', 'Website ID copied'),
    );
  }

  void _startAutoEnterDataCountdown() {
    _autoEnterTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _installSucceeded = true;
      _installError = null;
      _autoEnterCountdown = 3;
    });
    _autoEnterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_autoEnterCountdown <= 1) {
        timer.cancel();
        _enterDataView();
        return;
      }
      setState(() {
        _autoEnterCountdown -= 1;
      });
    });
  }

  void _enterDataView() {
    _autoEnterTimer?.cancel();
    if (!mounted) return;
    if (!_hasAnalyticsEnabled) return;
    setState(() {
      _showInstallerView = false;
      _installSucceeded = false;
      _autoEnterCountdown = 0;
      _analyticsTabIndex = 0;
    });
  }

  Future<void> _copyFieldValue(String value, String label) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: _t('copied', 'Copied'),
      message: _t(
        'project_analytics_field_copied',
        '{label} copied',
      ).replaceAll('{label}', label),
    );
  }

  Future<void> _shareAnalyticsAccess() async {
    if (_sharingAccess) return;
    setState(() {
      _sharingAccess = true;
    });

    try {
      final data = await _d1vaiService.bindAnalyticsUser(widget.project.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final loginUrl = (data['analytics_login_url'] ?? '').toString();
          final username = (data['analytics_username'] ?? '').toString();
          final password = (data['analytics_password'] ?? '').toString();
          final teamCode = (data['analytics_team_code'] ?? '').toString();

          Widget row(String title, String value) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        value.isEmpty ? '—' : value,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: value.trim().isEmpty
                          ? null
                          : () => _copyFieldValue(value, title),
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: _t(
                        'project_analytics_copy_field',
                        'Copy {title}',
                      ).replaceAll('{title}', title),
                    ),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(
              _t(
                'project_analytics_share_access_dialog',
                'Share Analytics Access',
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(_t('project_analytics_login_url', 'Login URL'), loginUrl),
                  const SizedBox(height: 12),
                  row(_t('project_analytics_username', 'Username'), username),
                  const SizedBox(height: 12),
                  row(_t('project_analytics_password', 'Password'), password),
                  const SizedBox(height: 12),
                  row(
                    _t(
                      'project_analytics_team_access_code',
                      'Team Access Code',
                    ),
                    teamCode,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_t('close', 'Close')),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('success', 'Success'),
        message: _t(
          'project_analytics_access_ready',
          'Analytics access is ready to share.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: humanizeError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharingAccess = false;
        });
      }
    }
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
    if (_showPageviewsSeries && pageviews.isNotEmpty) {
      series.add(
        ChartSeries(
          name: _t('project_analytics_pageviews', 'Pageviews'),
          data: pageviews,
          color: Colors.blue,
        ),
      );
    }
    if (_showSessionsSeries && sessions.isNotEmpty) {
      series.add(
        ChartSeries(
          name: _t('project_analytics_sessions', 'Sessions'),
          data: sessions,
          color: Colors.green,
        ),
      );
    }
    return series;
  }

  String _timeRangeLabel(TimeRange range) {
    return switch (range) {
      TimeRange.lastHour => _t('project_analytics_last_hour', 'Last Hour'),
      TimeRange.last6Hours => _t(
        'project_analytics_last_6_hours',
        'Last 6 Hours',
      ),
      TimeRange.last24Hours => _t(
        'project_analytics_last_24_hours',
        'Last 24 Hours',
      ),
      TimeRange.last7Days => _t('project_analytics_last_7_days', 'Last 7 Days'),
      TimeRange.last30Days => _t(
        'project_analytics_last_30_days',
        'Last 30 Days',
      ),
      TimeRange.last90Days => _t(
        'project_analytics_last_90_days',
        'Last 90 Days',
      ),
    };
  }

  String _compareDimLabel(String dim) {
    return switch (dim) {
      'pages' => _t('project_analytics_dim_pages', 'Pages'),
      'referrers' => _t('project_analytics_dim_referrers', 'Referrers'),
      'browsers' => _t('project_analytics_dim_browsers', 'Browsers'),
      'os' => _t('project_analytics_dim_os', 'OS'),
      'devices' => _t('project_analytics_dim_devices', 'Devices'),
      'screen' => _t('project_analytics_dim_screen', 'Screen'),
      'countries' => _t('project_analytics_dim_countries', 'Countries'),
      'regions' => _t('project_analytics_dim_regions', 'Regions'),
      'cities' => _t('project_analytics_dim_cities', 'Cities'),
      'languages' => _t('project_analytics_dim_languages', 'Languages'),
      'events' => _t('project_analytics_dim_events', 'Events'),
      'query' => _t('project_analytics_dim_query', 'Query'),
      'tag' => _t('project_analytics_dim_tag', 'Tag'),
      'channel' => _t('project_analytics_dim_channel', 'Channel'),
      'host' => _t('project_analytics_dim_host', 'Host'),
      _ => dim,
    };
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowInstaller =
        _showInstallerView ||
        (!_hasAnalyticsEnabled &&
            (_installing ||
                _installMessages.isNotEmpty ||
                _installError != null));

    if (shouldShowInstaller) {
      return _AnalyticsInstallerView(
        installing: _installing,
        installSucceeded: _installSucceeded,
        autoEnterCountdown: _autoEnterCountdown,
        isTyping: _installTyping,
        websiteId: _websiteId,
        error: _installError,
        messages: _installMessages,
        onCopyWebsiteId: _copyWebsiteId,
        onRetry: _enableAndInstallAnalytics,
        onSeeData: _enterDataView,
        onReset: () {
          _autoEnterTimer?.cancel();
          _closeInstallerWebSocket();
          setState(() {
            _installing = false;
            _installTyping = false;
            _installError = null;
            _installMessages = [];
            _websiteId = null;
            _showInstallerView = false;
            _installSucceeded = false;
            _autoEnterCountdown = 0;
          });
        },
      );
    }

    if (!_hasAnalyticsEnabled) {
      return _EnableAnalyticsCard(
        enabling: _installing,
        onEnable: _enableAndInstallAnalytics,
      );
    }

    return _buildEnabledTabsView();
  }

  Map<String, int> _timeBoundsMs() {
    final now = DateTime.now();
    final endAt = now.millisecondsSinceEpoch;
    final startAt = endAt - _timeRange.duration.inMilliseconds;
    return {'startAt': startAt, 'endAt': endAt};
  }

  Map<String, int> _eventsBoundsMs() {
    final now = DateTime.now();
    final endAt = now.millisecondsSinceEpoch;
    final duration = _eventsTimeRange == TimeRange.last30Days
        ? TimeRange.last30Days.duration
        : TimeRange.last7Days.duration;
    final startAt = endAt - duration.inMilliseconds;
    return {'startAt': startAt, 'endAt': endAt};
  }

  double _percentChange(int current, int previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  int _sumPoints(dynamic raw) {
    if (raw is! List) return 0;
    var sum = 0;
    for (final it in raw) {
      if (it is! Map) continue;
      sum += _asInt(it['y'] ?? it['value']);
    }
    return sum;
  }

  List<MetricDataPoint> _toMetricPoints(dynamic raw) {
    if (raw is! List) return const [];
    final points = <MetricDataPoint>[];
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
      points.add(
        MetricDataPoint(
          timestamp: ts ?? DateTime.now(),
          value: y is num ? y.toDouble() : double.tryParse('$y') ?? 0,
          label: x?.toString(),
        ),
      );
    }
    return points;
  }

  Widget _buildEnabledTabsView() {
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              onTap: (index) {
                if (_analyticsTabIndex == index) return;
                setState(() {
                  _analyticsTabIndex = index;
                });
              },
              tabs: [
                Tab(text: _t('project_analytics_tab_data', 'Data')),
                Tab(text: _t('project_analytics_tab_events', 'Events')),
                Tab(text: _t('project_analytics_tab_sessions', 'Sessions')),
                Tab(text: _t('project_analytics_tab_realtime', 'Realtime')),
                Tab(text: _t('project_analytics_tab_compare', 'Compare')),
                Tab(text: _t('project_analytics_tab_reports', 'Reports')),
                Tab(text: _t('project_analytics_tab_setting', 'Setting')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _analyticsTabIndex == 0
                    ? _buildDataTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_data', 'Data'),
                      ),
                _analyticsTabIndex == 1
                    ? _buildEventsTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_events', 'Events'),
                      ),
                _analyticsTabIndex == 2
                    ? _buildSessionsTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_sessions', 'Sessions'),
                      ),
                _analyticsTabIndex == 3
                    ? _buildRealtimeTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_realtime', 'Realtime'),
                      ),
                _analyticsTabIndex == 4
                    ? _buildCompareTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_compare', 'Compare'),
                      ),
                _analyticsTabIndex == 5
                    ? _buildReportsTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_reports', 'Reports'),
                      ),
                _analyticsTabIndex == 6
                    ? _buildSettingsTabView()
                    : _inactiveTabPlaceholder(
                        _t('project_analytics_tab_setting', 'Setting'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inactiveTabPlaceholder(String title) {
    return Center(
      child: Text(
        _t(
          'project_analytics_inactive_tab',
          '{title} tab',
        ).replaceAll('{title}', title),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildDataTabView() {
    final theme = Theme.of(context);
    final hasAnyData =
        _values != null ||
        _pageviews != null ||
        _activeVisitors != null ||
        _topPages.isNotEmpty ||
        _topReferrers.isNotEmpty;

    if (_isLoading && !hasAnyData) {
      return const AnalyticsDataSkeleton();
    }

    if (!hasAnyData) {
      final msg = (_loadError ?? '').trim().isNotEmpty
          ? _loadError!.trim()
          : _t(
              'project_analytics_no_data_hint',
              'Analytics data will appear once your project is live and receiving traffic.',
            );
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _t('project_analytics_no_data', 'No analytics data yet'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalytics,
                child: Text(_t('retry', 'Retry')),
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
            _buildFiltersCard(),
            const SizedBox(height: 16),
            _buildPeriodCard(),
            const SizedBox(height: 16),
            _buildKeyMetricsRow(),
            const SizedBox(height: 16),
            if (_pageviews != null) ...[
              if (_trafficSeries.isNotEmpty)
                RealtimeChart(
                  title: _t(
                    'project_analytics_traffic_overview',
                    'Traffic Overview',
                  ),
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
                )
              else
                _buildSeriesEmptyCard(),
              const SizedBox(height: 16),
            ],
            _buildTopListsCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) return data;
      final events = raw['events'];
      if (events is List) return events;
      final results = raw['results'];
      if (results is List) return results;
    }
    return const <dynamic>[];
  }

  bool _isRecoverableAnalyticsFetchError(Object error) {
    final msg = error.toString();
    if (isAuthExpiredText(msg)) return false;
    final m = msg.toLowerCase();
    if (m.contains('401') || m.contains('unauthorized')) return false;
    return m.contains('400') ||
        m.contains('404') ||
        m.contains('500') ||
        m.contains('502') ||
        m.contains('http error') ||
        m.contains('internal error');
  }

  Future<Map<String, dynamic>> _fetchEventsSnapshot() async {
    final bounds = _eventsBoundsMs();
    final startAt = bounds['startAt']!;
    final endAt = bounds['endAt']!;
    final filters = _buildEnvFilters();
    List<dynamic> events = const <dynamic>[];
    Map<String, dynamic> stats = const <String, dynamic>{};
    List<dynamic> series = const <dynamic>[];

    try {
      final rawEvents = await _d1vaiService.getUmamiEvents(
        widget.project.id,
        startAt: startAt,
        endAt: endAt,
        filters: filters,
      );
      events = _asList(rawEvents);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Events API fallback: $e');
    }

    try {
      final rawStats = await _d1vaiService.getUmamiEventDataStats(
        widget.project.id,
        startAt: startAt,
        endAt: endAt,
        filters: filters,
      );
      stats = _asMap(rawStats);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Event stats API fallback: $e');
    }

    try {
      final rawSeries = await _d1vaiService.getUmamiEventMetrics(
        widget.project.id,
        {'startAt': startAt, 'endAt': endAt, 'unit': 'day', 'timezone': 'UTC'},
        filters: filters,
      );
      series = _asList(rawSeries);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Events series API fallback: $e');
    }

    if (events.isEmpty) {
      try {
        final fallbackMetrics = await _d1vaiService.getUmamiMetrics(
          widget.project.id,
          {'type': 'event', 'startAt': startAt, 'endAt': endAt, 'limit': 20},
          filters: filters,
        );
        events = _asList(fallbackMetrics);
      } catch (e) {
        if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
        debugPrint('Events metrics fallback failed: $e');
      }
    }

    return {'events': events, 'stats': stats, 'series': series};
  }

  Widget _buildEventsTabView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchEventsSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AnalyticsEventsSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 8),
                  Text(humanizeError(snapshot.error ?? 'Unknown error')),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() {}),
                    child: Text(_t('retry', 'Retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final events = payload['events'] as List<dynamic>? ?? const [];
        final stats =
            payload['stats'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final points = _toMetricPoints(payload['series']);
        final uniqueEvents = stats['events'] is List
            ? (stats['events'] as List).length
            : _asInt(stats['unique']);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(_t('project_analytics_7d', '7D')),
                    selected: _eventsTimeRange == TimeRange.last7Days,
                    onSelected: (v) {
                      if (!v || _eventsTimeRange == TimeRange.last7Days) {
                        return;
                      }
                      setState(() => _eventsTimeRange = TimeRange.last7Days);
                    },
                  ),
                  ChoiceChip(
                    label: Text(_t('project_analytics_30d', '30D')),
                    selected: _eventsTimeRange == TimeRange.last30Days,
                    onSelected: (v) {
                      if (!v || _eventsTimeRange == TimeRange.last30Days) {
                        return;
                      }
                      setState(() => _eventsTimeRange = TimeRange.last30Days);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _simpleMetricCard(
                      title: _t(
                        'project_analytics_total_events',
                        'Total Events',
                      ),
                      value: events.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _simpleMetricCard(
                      title: _t(
                        'project_analytics_unique_events',
                        'Unique Events',
                      ),
                      value: uniqueEvents.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (points.isNotEmpty)
                RealtimeChart(
                  title: _t('project_analytics_events_trend', 'Events Trend'),
                  series: [
                    ChartSeries(
                      name: _t('project_analytics_events', 'Events'),
                      data: points,
                      color: Colors.orange,
                    ),
                  ],
                  timeRange: _eventsTimeRange,
                  height: 230,
                  showLegend: false,
                  onTimeRangeChanged: (range) {
                    final normalized = range == TimeRange.last30Days
                        ? TimeRange.last30Days
                        : TimeRange.last7Days;
                    if (normalized == _eventsTimeRange) return;
                    setState(() {
                      _eventsTimeRange = normalized;
                    });
                  },
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('project_analytics_recent_events', 'Recent Events'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (events.isEmpty)
                        Text(
                          _t(
                            'project_analytics_no_events',
                            'No events in current range',
                          ),
                        )
                      else
                        ...events.take(12).map((e) {
                          final item = e is Map ? e : const {};
                          final name =
                              (item['x'] ??
                                      item['eventName'] ??
                                      item['name'] ??
                                      '—')
                                  .toString();
                          final count = _asInt(item['y'] ?? item['value']);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(name),
                            trailing: Text(count.toString()),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchSessionsSnapshot() async {
    final bounds = _timeBoundsMs();
    final startAt = bounds['startAt']!;
    final endAt = bounds['endAt']!;
    try {
      final payload = await _d1vaiService.getUmamiSessions(widget.project.id, {
        'startAt': startAt,
        'endAt': endAt,
        'page': 1,
        'pageSize': 20,
      }, filters: _buildEnvFilters());
      return _asMap(payload);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Sessions API fallback: $e');
      return const <String, dynamic>{'data': <dynamic>[], 'count': 0};
    }
  }

  Widget _buildSessionsTabView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSessionsSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AnalyticsSessionsSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(humanizeError(snapshot.error ?? 'Unknown error')),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final sessions = payload['data'] is List
            ? payload['data'] as List<dynamic>
            : const <dynamic>[];
        final count = _asInt(payload['count']);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _simpleMetricCard(
                title: _t('project_analytics_total_sessions', 'Total Sessions'),
                value: count.toString(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('project_analytics_session_list', 'Session List'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (sessions.isEmpty)
                        Text(
                          _t(
                            'project_analytics_no_sessions',
                            'No sessions in current range',
                          ),
                        )
                      else
                        ...sessions.take(12).map((s) {
                          final item = s is Map ? s : const {};
                          final title =
                              (item['path'] ??
                                      item['url'] ??
                                      item['hostname'] ??
                                      item['sessionId'] ??
                                      _t(
                                        'project_analytics_session',
                                        'Session',
                                      ))
                                  .toString();
                          final subtitle =
                              (item['browser'] ??
                                      item['os'] ??
                                      item['device'] ??
                                      '')
                                  .toString();
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            subtitle: subtitle.trim().isEmpty
                                ? null
                                : Text(subtitle),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchRealtimeSnapshot() async {
    Map<String, dynamic> realtime = const <String, dynamic>{};
    Map<String, dynamic> active = const <String, dynamic>{};

    try {
      final payload = await _d1vaiService.getUmamiRealtime(widget.project.id);
      realtime = _asMap(payload);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Realtime API fallback: $e');
    }

    try {
      final payload = await _d1vaiService.getUmamiActiveVisitors(
        widget.project.id,
      );
      active = _asMap(payload);
    } catch (e) {
      if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
      debugPrint('Active visitors API fallback: $e');
    }

    if (realtime.isEmpty && active.isNotEmpty) {
      realtime = {'visitors': _asInt(active['x'] ?? active['visitors'])};
    }

    return {'realtime': realtime, 'active': active};
  }

  Widget _buildRealtimeTabView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchRealtimeSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(humanizeError(snapshot.error ?? 'Unknown error')),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final realtime =
            payload['realtime'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final active =
            payload['active'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final activeNow = _asInt(active['x'] ?? realtime['visitors']);
        final urlMap = realtime['urls'];
        final topUrls = urlMap is Map
            ? urlMap.entries
                  .map(
                    (e) => {'url': e.key.toString(), 'count': _asInt(e.value)},
                  )
                  .toList()
            : const <Map<String, dynamic>>[];

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _simpleMetricCard(
                title: _t(
                  'project_analytics_active_visitors',
                  'Active Visitors',
                ),
                value: activeNow.toString(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          'project_analytics_top_urls_realtime',
                          'Top URLs (Realtime)',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (topUrls.isEmpty)
                        Text(
                          _t(
                            'project_analytics_no_realtime_urls',
                            'No realtime URL data yet',
                          ),
                        )
                      else
                        ...topUrls
                            .take(10)
                            .map(
                              (it) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text((it['url'] ?? '—').toString()),
                                trailing: Text(_asInt(it['count']).toString()),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchCompareSnapshot() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final days = _compareMode == AnalyticsCompareMode.days7 ? 7 : 30;
    final span = Duration(days: days).inMilliseconds;
    final compareMetricType = _compareDimToApiType[_compareDimension] ?? 'path';
    final currentStart = now - span;
    final previousStart = now - span * 2;
    final previousEnd = now - span;
    final filters = _buildEnvFilters();

    Future<Map<String, dynamic>> fetchRange({
      required int startAt,
      required int endAt,
    }) async {
      try {
        final payload = await _d1vaiService.getUmamiPageviews(
          widget.project.id,
          {
            'unit': 'day',
            'timezone': 'UTC',
            'startAt': startAt,
            'endAt': endAt,
          },
          filters: filters,
        );
        return _asMap(payload);
      } catch (e) {
        if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
        debugPrint('Compare pageviews API fallback: $e');
        return const <String, dynamic>{};
      }
    }

    Future<List<dynamic>> fetchMetricsRange({
      required int startAt,
      required int endAt,
    }) async {
      try {
        final payload = await _d1vaiService.getUmamiMetrics(widget.project.id, {
          'type': compareMetricType,
          'startAt': startAt,
          'endAt': endAt,
          'limit': 20,
        }, filters: filters);
        return payload;
      } catch (e) {
        if (!_isRecoverableAnalyticsFetchError(e)) rethrow;
        debugPrint('Compare metrics API fallback: $e');
        return const <dynamic>[];
      }
    }

    final results = await Future.wait<dynamic>([
      fetchRange(startAt: currentStart, endAt: now),
      fetchRange(startAt: previousStart, endAt: previousEnd),
      fetchMetricsRange(startAt: currentStart, endAt: now),
      fetchMetricsRange(startAt: previousStart, endAt: previousEnd),
    ]);

    return {
      'current': results[0],
      'previous': results[1],
      'currentMetrics': results[2],
      'previousMetrics': results[3],
    };
  }

  Widget _buildCompareTabView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchCompareSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(humanizeError(snapshot.error ?? 'Unknown error')),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final current =
            payload['current'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final previous =
            payload['previous'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final currentMetrics = payload['currentMetrics'] is List
            ? payload['currentMetrics'] as List<dynamic>
            : const <dynamic>[];
        final previousMetrics = payload['previousMetrics'] is List
            ? payload['previousMetrics'] as List<dynamic>
            : const <dynamic>[];
        final currentPv = _sumPoints(current['pageviews']);
        final prevPv = _sumPoints(previous['pageviews']);
        final currentSessions = _sumPoints(current['sessions']);
        final prevSessions = _sumPoints(previous['sessions']);

        final pvDelta = _percentChange(currentPv, prevPv);
        final sessionDelta = _percentChange(currentSessions, prevSessions);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      _t('project_analytics_7d_vs_prev', '7D vs Prev 7D'),
                    ),
                    selected: _compareMode == AnalyticsCompareMode.days7,
                    onSelected: (v) {
                      if (!v || _compareMode == AnalyticsCompareMode.days7) {
                        return;
                      }
                      setState(() => _compareMode = AnalyticsCompareMode.days7);
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      _t('project_analytics_30d_vs_prev', '30D vs Prev 30D'),
                    ),
                    selected: _compareMode == AnalyticsCompareMode.days30,
                    onSelected: (v) {
                      if (!v || _compareMode == AnalyticsCompareMode.days30) {
                        return;
                      }
                      setState(
                        () => _compareMode = AnalyticsCompareMode.days30,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _compareDimToApiType.keys.map((dim) {
                    final selected = _compareDimension == dim;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_compareDimLabel(dim)),
                        selected: selected,
                        onSelected: (v) {
                          if (!v || selected) return;
                          setState(() => _compareDimension = dim);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _simpleMetricCard(
                      title: _t('project_analytics_pageviews', 'Pageviews'),
                      value: '$currentPv (${pvDelta.toStringAsFixed(1)}%)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _simpleMetricCard(
                      title: _t('project_analytics_sessions', 'Sessions'),
                      value:
                          '$currentSessions (${sessionDelta.toStringAsFixed(1)}%)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          'project_analytics_comparison_notes',
                          'Comparison Notes',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'project_analytics_current_window',
                          'Current window: {range}',
                        ).replaceAll(
                          '{range}',
                          _compareMode == AnalyticsCompareMode.days7
                              ? _t(
                                  'project_analytics_last_7_days',
                                  'Last 7 Days',
                                )
                              : _t(
                                  'project_analytics_last_30_days',
                                  'Last 30 Days',
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          'project_analytics_previous_window',
                          'Previous window: previous {range}',
                        ).replaceAll(
                          '{range}',
                          _compareMode == AnalyticsCompareMode.days7
                              ? _t(
                                  'project_analytics_last_7_days',
                                  'Last 7 Days',
                                )
                              : _t(
                                  'project_analytics_last_30_days',
                                  'Last 30 Days',
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                              'project_analytics_pageviews_compare',
                              'Pageviews: {current} vs {previous}',
                            )
                            .replaceAll('{current}', currentPv.toString())
                            .replaceAll('{previous}', prevPv.toString()),
                      ),
                      Text(
                        _t(
                              'project_analytics_sessions_compare',
                              'Sessions: {current} vs {previous}',
                            )
                            .replaceAll('{current}', currentSessions.toString())
                            .replaceAll('{previous}', prevSessions.toString()),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t(
                          'project_analytics_top_compare',
                          'Top {dimension} (Current vs Previous)',
                        ).replaceAll(
                          '{dimension}',
                          _compareDimLabel(_compareDimension),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (currentMetrics.isEmpty && previousMetrics.isEmpty)
                        Text(
                          _t(
                            'project_analytics_no_compare_data',
                            'No top-page comparison data',
                          ),
                        )
                      else
                        ..._buildCompareMetricRows(
                          currentMetrics,
                          previousMetrics,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCompareMetricRows(
    List<dynamic> currentMetrics,
    List<dynamic> previousMetrics,
  ) {
    final previousMap = <String, int>{};
    for (final item in previousMetrics) {
      if (item is! Map) continue;
      final name =
          (item['x'] ?? item['name'] ?? item['path'] ?? item['url'] ?? '')
              .toString()
              .trim();
      if (name.isEmpty) continue;
      previousMap[name] = _asInt(item['y'] ?? item['value']);
    }

    final rows = <Widget>[];
    for (final item in currentMetrics.take(8)) {
      if (item is! Map) continue;
      final name =
          (item['x'] ?? item['name'] ?? item['path'] ?? item['url'] ?? '—')
              .toString()
              .trim();
      final current = _asInt(item['y'] ?? item['value']);
      final previous = previousMap[name] ?? 0;
      final delta = _percentChange(current, previous);
      rows.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(name.isEmpty ? '—' : name),
          subtitle: Text(
            _t(
              'project_analytics_prev',
              'Prev: {value}',
            ).replaceAll('{value}', previous.toString()),
          ),
          trailing: Text('$current (${delta.toStringAsFixed(1)}%)'),
        ),
      );
    }
    return rows;
  }

  Widget _buildReportsTabView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('project_analytics_reports', 'Reports'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'project_analytics_reports_coming',
                    'Custom reports are coming soon. This keeps parity with the current web placeholder state.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTabView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _d1vaiService.getProjectAnalyticsTrackingCode(widget.project.id),
      builder: (context, snapshot) {
        final tracking = snapshot.data ?? const <String, dynamic>{};
        final websiteId = (tracking['website_id'] ?? widget.project.analyticsId)
            .toString();
        final trackingCode = (tracking['tracking_code'] ?? '').toString();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('project_analytics_tracking', 'Analytics Tracking'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'project_analytics_website_id',
                        'Website ID: {id}',
                      ).replaceAll(
                        '{id}',
                        websiteId.trim().isEmpty ? '—' : websiteId,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (trackingCode.trim().isNotEmpty)
                      SelectableText(
                        trackingCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      )
                    else
                      Text(
                        _t(
                          'project_analytics_tracking_unavailable',
                          'Tracking code unavailable',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionsCard(),
          ],
        );
      },
    );
  }

  Widget _simpleMetricCard({required String title, required String value}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesEmptyCard() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('project_analytics_traffic_overview', 'Traffic Overview'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'project_analytics_no_metrics_selected',
                'No metrics selected. Enable Pageviews/Sessions in Filters.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPageviewsSeries = true;
                    _showSessionsSeries = true;
                    if (_pageviews != null) {
                      _trafficSeries = _createTrafficSeries(_pageviews!);
                    }
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  _t('project_analytics_restore_defaults', 'Restore defaults'),
                ),
              ),
            ),
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMd(locale).add_Hm();
    return '${fmt.format(start.toLocal())} → ${fmt.format(now.toLocal())}';
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

  Widget _buildFiltersCard() {
    final theme = Theme.of(context);
    final previewHost = _previewHost;
    final prodHost = _prodHost;

    Widget chipRow(List<Widget> children) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: children),
      );
    }

    Future<void> reload() async {
      await _loadAnalytics();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _t('project_analytics_filters', 'Filters'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _timeRange = TimeRange.last24Hours;
                            _eventsTimeRange = TimeRange.last7Days;
                            _envScope = AnalyticsEnvScope.all;
                            _showPageviewsSeries = true;
                            _showSessionsSeries = true;
                            if (_pageviews != null) {
                              _trafficSeries = _createTrafficSeries(
                                _pageviews!,
                              );
                            }
                          });
                          reload();
                        },
                  child: Text(_t('project_analytics_reset', 'Reset')),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _t('project_analytics_time_range', 'Time range'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            chipRow([
              for (final r in const [
                TimeRange.last24Hours,
                TimeRange.last7Days,
                TimeRange.last30Days,
                TimeRange.last90Days,
              ])
                ChoiceChip(
                  label: Text(_timeRangeLabel(r)),
                  selected: _timeRange == r,
                  onSelected: (v) {
                    if (!v || _timeRange == r) return;
                    setState(() => _timeRange = r);
                    reload();
                  },
                ),
            ]),
            const SizedBox(height: 12),
            Text(
              _t('project_analytics_environment', 'Environment'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            chipRow([
              ChoiceChip(
                label: Text(_t('project_analytics_all', 'All')),
                selected: _envScope == AnalyticsEnvScope.all,
                onSelected: (v) {
                  if (!v || _envScope == AnalyticsEnvScope.all) return;
                  setState(() => _envScope = AnalyticsEnvScope.all);
                  reload();
                },
              ),
              ChoiceChip(
                label: Text(_t('project_analytics_preview', 'Preview')),
                selected: _envScope == AnalyticsEnvScope.preview,
                onSelected: previewHost == null
                    ? null
                    : (v) {
                        if (!v || _envScope == AnalyticsEnvScope.preview) {
                          return;
                        }
                        setState(() => _envScope = AnalyticsEnvScope.preview);
                        reload();
                      },
              ),
              ChoiceChip(
                label: Text(_t('project_analytics_prod', 'Prod')),
                selected: _envScope == AnalyticsEnvScope.prod,
                onSelected: prodHost == null
                    ? null
                    : (v) {
                        if (!v || _envScope == AnalyticsEnvScope.prod) return;
                        setState(() => _envScope = AnalyticsEnvScope.prod);
                        reload();
                      },
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              _t('project_analytics_metrics', 'Metrics'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            chipRow([
              FilterChip(
                label: Text(_t('project_analytics_pageviews', 'Pageviews')),
                selected: _showPageviewsSeries,
                onSelected: (v) {
                  setState(() {
                    _showPageviewsSeries = v;
                    if (_pageviews != null) {
                      _trafficSeries = _createTrafficSeries(_pageviews!);
                    }
                  });
                },
              ),
              FilterChip(
                label: Text(_t('project_analytics_sessions', 'Sessions')),
                selected: _showSessionsSeries,
                onSelected: (v) {
                  setState(() {
                    _showSessionsSeries = v;
                    if (_pageviews != null) {
                      _trafficSeries = _createTrafficSeries(_pageviews!);
                    }
                  });
                },
              ),
            ]),
            if (_envScope != AnalyticsEnvScope.all) ...[
              const SizedBox(height: 10),
              Text(
                _t(
                  'project_analytics_env_filter_note',
                  'Note: environment filter uses hostname exact matching.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                    _t(
                      'project_analytics_period',
                      'Period: {range}',
                    ).replaceAll('{range}', _timeRangeLabel(_timeRange)),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeRangeLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                title: _t('project_analytics_pageviews', 'Pageviews'),
                value: pageviews.toString(),
                icon: Icons.visibility,
                color: Colors.blue,
                onTap: () {
                  widget.onAskAi?.call(
                    _t(
                      'project_analytics_ai_prompt_pageviews',
                      'Can you analyze my pageviews trend and suggest ways to increase traffic and retention?',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: _t('project_analytics_visitors', 'Visitors'),
                value: visitors.toString(),
                icon: Icons.people,
                color: Colors.purple,
                onTap: () {
                  widget.onAskAi?.call(
                    _t(
                      'project_analytics_ai_prompt_visitors',
                      'Can you analyze my visitor acquisition and suggest improvements (SEO, referrers, landing pages)?',
                    ),
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
                title: _t('project_analytics_sessions', 'Sessions'),
                value: sessions.toString(),
                icon: Icons.timeline,
                color: Colors.teal,
                onTap: () {
                  widget.onAskAi?.call(
                    _t(
                      'project_analytics_ai_prompt_sessions',
                      'Can you analyze my sessions and suggest how to increase engagement and session duration?',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsMetricCard(
                title: _t('project_analytics_active_now', 'Active Now'),
                value: activeNow.toString(),
                icon: Icons.bolt,
                color: Colors.indigo,
                onTap: () {
                  widget.onAskAi?.call(
                    _t(
                      'project_analytics_ai_prompt_active_now',
                      'Can you help me interpret my real-time active users and recommend actions to improve conversion?',
                    ),
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
            Text(
              _t('project_analytics_status_summary', 'Status Summary'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('project_analytics_bounces', 'Bounces'),
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
                      Text(
                        _t('project_analytics_total_time', 'Total time'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalTimeSeconds > 0
                            ? _t(
                                'project_analytics_total_minutes',
                                '{minutes} min',
                              ).replaceAll(
                                '{minutes}',
                                (totalTimeSeconds / 60).toStringAsFixed(1),
                              )
                            : (visits > 0
                                  ? _t(
                                      'project_analytics_visits_count',
                                      '{count} visits',
                                    ).replaceAll('{count}', visits.toString())
                                  : '—'),
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
      if (it is Map) {
        return (it['x'] ?? it['name'] ?? it['label'] ?? '—').toString();
      }
      return it.toString();
    }

    String itemValue(dynamic it) {
      if (it is Map) return _asInt(it['y'] ?? it['value']).toString();
      return '';
    }

    Widget buildList(String title, List<dynamic> items) {
      final theme = Theme.of(context);
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
                _t('project_analytics_no_data_short', 'No data'),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                          color: theme.colorScheme.onSurfaceVariant,
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
            Text(
              _t(
                'project_analytics_top_traffic_sources',
                'Top Traffic Sources',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildList(
                  _t('project_analytics_top_pages', 'Top pages'),
                  pages,
                ),
                const SizedBox(width: 16),
                buildList(
                  _t('project_analytics_top_referrers', 'Top referrers'),
                  refs,
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
            Text(
              _t('project_analytics_actions', 'Actions'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.indigo),
              title: Text(
                _t('project_analytics_reenable', 'Re-enable Analytics'),
              ),
              subtitle: Text(
                _t(
                  'project_analytics_reenable_hint',
                  'Re-run script installation flow',
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _installing ? null : _reEnableAnalytics,
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.share,
                color: _sharingAccess ? Colors.grey : Colors.teal,
              ),
              title: Text(_t('project_analytics_share_access', 'Share Access')),
              subtitle: Text(
                _t(
                  'project_analytics_share_access_hint',
                  'Create credentials for Umami login',
                ),
              ),
              trailing: _sharingAccess
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _sharingAccess ? null : _shareAnalyticsAccess,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.copy_all, color: Colors.green),
              title: Text(_t('project_analytics_copy_summary', 'Copy Summary')),
              subtitle: Text(
                _t(
                  'project_analytics_copy_summary_hint',
                  'Copy a shareable analytics snapshot',
                ),
              ),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: _copyAnalyticsSummary,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.deepPurple),
              title: Text(
                _t(
                  'project_analytics_copy_tracking_code',
                  'Copy Tracking Code',
                ),
              ),
              subtitle: Text(
                _t(
                  'project_analytics_copy_tracking_code_hint',
                  'Copy Umami script snippet',
                ),
              ),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: _copyTrackingCode,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: Text(
                _t(
                  'project_analytics_view_dashboard',
                  'View Detailed Dashboard',
                ),
              ),
              subtitle: Text(
                _t(
                  'project_analytics_view_dashboard_hint',
                  'See comprehensive analytics',
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                widget.onAskAi?.call(
                  _t(
                    'project_analytics_ai_prompt_dashboard',
                    'Can you help me understand my analytics data and suggest ways to improve user engagement, performance, and overall metrics?',
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.track_changes, color: Colors.orange),
              title: Text(
                _t(
                  'project_analytics_track_custom_events',
                  'Track Custom Events',
                ),
              ),
              subtitle: Text(
                _t(
                  'project_analytics_track_custom_events_hint',
                  'Add custom tracking',
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                widget.onAskAi?.call(
                  _t(
                    'project_analytics_ai_prompt_custom_events',
                    'Can you guide me on setting up custom event tracking for my project? What are the most important events I should track to improve my product?',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAnalyticsSummary() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(_timeRange.duration);
      final buf = StringBuffer();
      buf.writeln(_t('project_analytics_summary_title', 'Analytics summary'));
      buf.writeln(
        _t(
          'project_analytics_summary_project',
          'Project: {name}',
        ).replaceAll('{name}', widget.project.projectName),
      );
      buf.writeln(
        _t(
          'project_analytics_summary_range',
          'Range: {range}',
        ).replaceAll('{range}', _timeRangeLabel(_timeRange)),
      );
      buf.writeln(
        _t('project_analytics_summary_window', 'Window: {start} → {end}')
            .replaceAll('{start}', start.toLocal().toIso8601String())
            .replaceAll('{end}', now.toLocal().toIso8601String()),
      );
      buf.writeln(
        _t(
          'project_analytics_summary_active_now',
          'Active now: {count}',
        ).replaceAll('{count}', _activeNow().toString()),
      );
      if (_values != null) {
        final visitors = _asInt(_values!['visitors'] ?? _values!['users']);
        final pageviews = _asInt(_values!['pageviews']);
        if (visitors > 0) {
          buf.writeln(
            _t(
              'project_analytics_summary_visitors',
              'Visitors: {count}',
            ).replaceAll('{count}', visitors.toString()),
          );
        }
        if (pageviews > 0) {
          buf.writeln(
            _t(
              'project_analytics_summary_pageviews',
              'Pageviews: {count}',
            ).replaceAll('{count}', pageviews.toString()),
          );
        }
      }
      if (_topPages.isNotEmpty) {
        buf.writeln('');
        buf.writeln(_t('project_analytics_top_pages_colon', 'Top pages:'));
        for (final p in _topPages.take(5)) {
          final m = (p is Map) ? p : null;
          final x = (m?['x'] ?? m?['path'] ?? m?['url'] ?? '').toString();
          final y = _asInt(m?['y'] ?? m?['count']);
          if (x.trim().isEmpty) continue;
          buf.writeln('- $x (${y > 0 ? y : '?'})');
        }
      }
      if (_topReferrers.isNotEmpty) {
        buf.writeln('');
        buf.writeln(
          _t('project_analytics_top_referrers_colon', 'Top referrers:'),
        );
        for (final p in _topReferrers.take(5)) {
          final m = (p is Map) ? p : null;
          final x = (m?['x'] ?? m?['referrer'] ?? '').toString();
          final y = _asInt(m?['y'] ?? m?['count']);
          if (x.trim().isEmpty) continue;
          buf.writeln('- $x (${y > 0 ? y : '?'})');
        }
      }

      final text = buf.toString().trim();
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('copied', 'Copied'),
        message: _t(
          'project_analytics_summary_copied',
          'Analytics summary copied',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_analytics_copy_failed', 'Copy failed'),
        message: humanizeError(e),
      );
    }
  }

  Future<void> _copyTrackingCode() async {
    try {
      final tracking = await _d1vaiService.getProjectAnalyticsTrackingCode(
        widget.project.id,
      );
      final code = (tracking['tracking_code'] ?? '').toString();
      if (code.trim().isEmpty) {
        throw Exception(
          _t('project_analytics_tracking_empty', 'Tracking code is empty'),
        );
      }
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('copied', 'Copied'),
        message: _t(
          'project_analytics_tracking_copied',
          'Tracking code copied',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_analytics_copy_failed', 'Copy failed'),
        message: humanizeError(e),
      );
    }
  }

  Future<void> _reEnableAnalytics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('project_analytics_reenable', 'Re-enable Analytics')),
        content: Text(
          _t(
            'project_analytics_reenable_confirm',
            'This will re-run analytics setup and re-insert the tracking script via workspace session. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_t('project_analytics_continue', 'Continue')),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;
    SnackBarHelper.showInfo(
      context,
      title: _t('project_analytics_started', 'Started'),
      message: _t(
        'project_analytics_reenable_started',
        'Re-enable process started.',
      ),
    );
    await _enableAndInstallAnalytics();
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
    final theme = Theme.of(context);
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

  const _EnableAnalyticsCard({required this.enabling, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key, String fallback) => _tr(context, key, fallback);

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
                    t('project_analytics_enable_title', 'Enable Analytics'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'project_analytics_enable_hint',
                      "Track your website's visitors, page views, and custom events with Umami Analytics",
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t(
                        'project_analytics_features_included',
                        'Features included:',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.visibility_outlined,
                    text: t(
                      'project_analytics_feature_realtime_visitors',
                      'Real-time visitor tracking',
                    ),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.mouse_outlined,
                    text: t(
                      'project_analytics_feature_pageviews_events',
                      'Page views and events',
                    ),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.people_outline,
                    text: t(
                      'project_analytics_feature_unique_visitors',
                      'Unique visitors analytics',
                    ),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _FeatureRow(
                    icon: Icons.trending_up,
                    text: t(
                      'project_analytics_feature_traffic_trends',
                      'Traffic trends over time',
                    ),
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
                        enabling
                            ? t(
                                'project_analytics_initializing',
                                'Initializing...',
                              )
                            : t(
                                'project_analytics_enable_action',
                                'Enable Analytics',
                              ),
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
  final bool installSucceeded;
  final int autoEnterCountdown;
  final bool isTyping;
  final String? websiteId;
  final String? error;
  final List<ChatMessage> messages;
  final Future<void> Function() onCopyWebsiteId;
  final VoidCallback onRetry;
  final VoidCallback onSeeData;
  final VoidCallback onReset;

  const _AnalyticsInstallerView({
    required this.installing,
    required this.installSucceeded,
    required this.autoEnterCountdown,
    required this.isTyping,
    required this.websiteId,
    required this.error,
    required this.messages,
    required this.onCopyWebsiteId,
    required this.onRetry,
    required this.onSeeData,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key, String fallback) => _tr(context, key, fallback);
    final showSuccess =
        installSucceeded && (error == null || error!.trim().isEmpty);

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
                          color: showSuccess
                              ? Colors.green.withValues(alpha: 0.12)
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          showSuccess ? Icons.check_circle : Icons.analytics,
                          color: showSuccess
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showSuccess
                                  ? t(
                                      'project_analytics_ready',
                                      'Analytics Ready',
                                    )
                                  : installing
                                  ? t(
                                      'project_analytics_installing',
                                      'Installing Analytics…',
                                    )
                                  : t(
                                      'project_analytics_installer',
                                      'Analytics Installer',
                                    ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              showSuccess
                                  ? (autoEnterCountdown > 0
                                        ? t(
                                            'project_analytics_install_done_autojump',
                                            'Installation completed. Auto-opening Data in {seconds}s.',
                                          ).replaceAll(
                                            '{seconds}',
                                            autoEnterCountdown.toString(),
                                          )
                                        : t(
                                            'project_analytics_install_done_open',
                                            'Installation completed. You can open the analytics tabs now.',
                                          ))
                                  : installing
                                  ? t(
                                      'project_analytics_installing_hint',
                                      'We are initializing Umami and inserting the tracking script via a chat session.',
                                    )
                                  : t(
                                      'project_analytics_installer_hint',
                                      'Review the session output or retry the install.',
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onReset,
                        tooltip: t('close', 'Close'),
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
                                  t(
                                    'project_analytics_website_id_title',
                                    'Website ID',
                                  ),
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
                            label: Text(t('copy', 'Copy')),
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
                  if (showSuccess)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onSeeData,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          autoEnterCountdown > 0
                              ? t(
                                  'project_analytics_see_data_countdown',
                                  'See data → ({seconds}s)',
                                ).replaceAll(
                                  '{seconds}',
                                  autoEnterCountdown.toString(),
                                )
                              : t('project_analytics_see_data', 'See data →'),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: installing ? null : onReset,
                            child: Text(t('back', 'Back')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: installing ? null : onRetry,
                            child: Text(
                              installing
                                  ? t('project_analytics_running', 'Running…')
                                  : t(
                                      'project_analytics_retry_install',
                                      'Retry Install',
                                    ),
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
