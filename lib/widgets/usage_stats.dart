import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../models/llm_usage.dart';
import '../models/db_usage.dart';
import '../models/builder_usage.dart';
import '../l10n/app_localizations.dart';
import 'skeletons/usage_stats_skeleton.dart';

class UsageStats extends StatefulWidget {
  const UsageStats({super.key});

  @override
  State<UsageStats> createState() => _UsageStatsState();
}

class _UsageStatsState extends State<UsageStats>
    with AutomaticKeepAliveClientMixin<UsageStats> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  bool _isLoadingLlm = false;
  bool _isLoadingBuilder = false;

  // Real database usage data (Neon consumption)
  DbUsageResponse? _dbUsage;
  // DB usage time window in days (default: last 30 days)
  final int _dbDaysRange = 30;

  // Real LLM usage data
  List<ProjectMonthlyUsage> _projectUsage = [];
  BuilderUsageSummary? _builderSummary;

  // LLM usage month selector
  int _selectedMonths = 12;
  final List<int> _availableMonths = [3, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load database usage from API (Neon consumption)
      try {
        final now = DateTime.now().toUtc();
        final from = now.subtract(Duration(days: _dbDaysRange));
        final dbUsage = await _usageService.getDbUsage(
          fromIso: from.toIso8601String(),
          toIso: now.toIso8601String(),
        );
        if (mounted) {
          setState(() {
            _dbUsage = dbUsage;
          });
        }
      } catch (e) {
        debugPrint('Failed to load DB usage: $e');
        // Don't show error for DB usage, it's optional
      }

      // Load LLM usage from API with selected months
      await _reloadLlmUsage();

      // Load builder usage summary (optional section)
      await _reloadBuilderUsage();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadLlmUsage() async {
    if (mounted) {
      setState(() {
        _isLoadingLlm = true;
      });
    }

    try {
      final llmUsage = await _usageService.getLlmUsage(_selectedMonths);
      if (mounted) {
        setState(() {
          _projectUsage = llmUsage.projects;
          _isLoadingLlm = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load LLM usage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load usage stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoadingLlm = false;
        });
      }
    }
  }

  Future<void> _reloadBuilderUsage() async {
    if (mounted) {
      setState(() {
        _isLoadingBuilder = true;
      });
    }

    try {
      final summary = await _usageService.getBuilderDurationSummary();
      if (mounted) {
        setState(() {
          _builderSummary = summary;
          _isLoadingBuilder = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load builder usage: $e');
      if (mounted) {
        setState(() {
          _builderSummary = null;
          _isLoadingBuilder = false;
        });
      }
    }
  }

  /// Calculate aggregated DB usage across all projects
  Map<String, double> _getAggregatedDbUsage() {
    if (_dbUsage == null || _dbUsage!.consumption.isEmpty) {
      return {
        'computeHours': 0.0,
        'activeHours': 0.0,
        'writtenGb': 0.0,
        'transferGb': 0.0,
        'storageGbHours': 0.0,
      };
    }

    double totalComputeSeconds = 0.0;
    double totalActiveSeconds = 0.0;
    double totalWrittenBytes = 0.0;
    double totalTransferBytes = 0.0;
    double totalStorageBytesHour = 0.0;

    for (final period in _dbUsage!.consumption) {
      totalComputeSeconds += period.computeTimeSeconds;
      totalActiveSeconds += period.activeTimeSeconds;
      totalWrittenBytes += period.writtenDataBytes;
      totalTransferBytes += period.dataTransferBytes;
      totalStorageBytesHour += period.dataStorageBytesHour;
    }

    const double gb = 1024.0 * 1024.0 * 1024.0;

    return {
      'computeHours': totalComputeSeconds / 3600.0,
      'activeHours': totalActiveSeconds / 3600.0,
      'writtenGb': totalWrittenBytes / gb,
      'transferGb': totalTransferBytes / gb,
      'storageGbHours': totalStorageBytesHour / gb,
    };
  }

  /// Calculate aggregated LLM usage from project data
  Map<String, dynamic> _getAggregatedLlmUsage() {
    if (_projectUsage.isEmpty) {
      return {'totalInput': 0, 'totalOutput': 0, 'totalCost': 0.0};
    }

    int totalInput = 0;
    int totalOutput = 0;
    double totalCost = 0.0;

    for (final project in _projectUsage) {
      totalInput += project.totalInputTokens;
      totalOutput += project.totalOutputTokens;
      totalCost += project.totalCostUsd;
    }

    return {
      'totalInput': totalInput,
      'totalOutput': totalOutput,
      'totalCost': totalCost,
    };
  }

  @override
  bool get wantKeepAlive => true;

  String _t(String key, String fallback) =>
      AppLocalizations.of(context)?.translate(key) ?? fallback;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build 来保持状态
    if (_isLoading) {
      return const UsageStatsSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _loadUsageStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            _t('orders_usage_db_title', 'Database Usage'),
            icon: Icons.storage_rounded,
          ),
          const SizedBox(height: 12),
          _buildDatabaseStatsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            _t('orders_usage_llm_title', 'LLM Usage'),
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          _buildMonthSelector(),
          const SizedBox(height: 12),
          _buildLLMStatsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            _t('orders_usage_builder_title', 'Builder Time'),
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 12),
          _buildBuilderStatsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            _t('orders_usage_project_breakdown_title', 'Project Breakdown'),
            icon: Icons.widgets_outlined,
          ),
          const SizedBox(height: 12),
          _buildProjectBreakdown(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDatabaseStatsCard() {
    // If no DB usage data or no consumption entries, show placeholder
    if (_dbUsage == null || _dbUsage!.consumption.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatRow(
                icon: Icons.storage,
                label: _t('orders_usage_db_title', 'Database Usage'),
                value: _t('orders_usage_na', 'N/A'),
                color: Colors.blue,
                subtitle: _t(
                  'orders_usage_db_empty_hint',
                  'No database usage data available yet',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final usage = _getAggregatedDbUsage();
    final computeHours = usage['computeHours'] ?? 0.0;
    final writtenGb = usage['writtenGb'] ?? 0.0;
    final transferGb = usage['transferGb'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow(
              icon: Icons.timer,
              label: _t('orders_usage_db_compute_time', 'Compute Time'),
              value: "${computeHours.toStringAsFixed(2)} h",
              color: Colors.blue,
              subtitle: _t(
                'orders_usage_db_compute_time_hint',
                'Total compute time (all projects)',
              ),
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.storage,
              label: _t('orders_usage_db_written_data', 'Written Data'),
              value: "${writtenGb.toStringAsFixed(2)} GB",
              color: Colors.green,
              subtitle: _t(
                'orders_usage_db_written_data_hint',
                'Total written data',
              ),
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.swap_horiz,
              label: _t('orders_usage_db_transfer', 'Data Transfer'),
              value: "${transferGb.toStringAsFixed(2)} GB",
              color: Colors.orange,
              subtitle: _t(
                'orders_usage_db_transfer_hint',
                'Total data transfer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLLMStatsCard() {
    final usage = _getAggregatedLlmUsage();

    if (_isLoadingLlm) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow(
              icon: Icons.token,
              label: _t('orders_usage_llm_input_tokens', 'Input Tokens'),
              value: _formatNumber(usage['totalInput']),
              color: Colors.purple,
              subtitle: _t(
                'orders_usage_llm_input_tokens_hint',
                'Total input tokens',
              ),
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.arrow_forward,
              label: _t('orders_usage_llm_output_tokens', 'Output Tokens'),
              value: _formatNumber(usage['totalOutput']),
              color: Colors.teal,
              subtitle: _t(
                'orders_usage_llm_output_tokens_hint',
                'Total output tokens',
              ),
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.attach_money,
              label: _t('orders_usage_llm_total_cost', 'Total Cost'),
              value: '\$${usage['totalCost'].toStringAsFixed(4)}',
              color: Colors.red,
              subtitle: _t(
                'orders_usage_llm_total_cost_hint',
                'Estimated cost',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double totalSeconds) {
    final sec = totalSeconds.isFinite ? totalSeconds.round() : 0;
    final clamped = sec < 0 ? 0 : sec;
    final h = clamped ~/ 3600;
    final m = (clamped % 3600) ~/ 60;
    final s = clamped % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Widget _buildBuilderStatsCard() {
    if (_isLoadingBuilder) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _builderSummary;
    if (summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'orders_usage_builder_load_failed',
                  'Unable to load builder usage data.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _reloadBuilderUsage,
                icon: const Icon(Icons.refresh),
                label: Text(_t('retry', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final rateText = summary.billingRateUsdPerMinute.toStringAsFixed(2);
    final projects = summary.projects.take(5).toList();
    final costText = summary.totalEstimatedCostUsd.toStringAsFixed(2);
    final totalDuration = _formatDuration(summary.totalBuildSeconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'orders_usage_builder_billing_rule',
                'Billing rule: {rate}/min',
              ).replaceAll('{rate}', '\$$rateText'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _buildStatRow(
              icon: Icons.schedule,
              label: _t('orders_usage_builder_overall', 'Overall Build Time'),
              value: totalDuration,
              color: Colors.indigo,
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.attach_money_rounded,
              label: _t(
                'orders_usage_builder_estimated_cost',
                'Estimated Cost',
              ),
              value: '\$$costText',
              color: Colors.deepOrange,
              subtitle: _t(
                'orders_usage_builder_estimated_cost_hint',
                'Estimated from deployment build durations',
              ),
            ),
            if (projects.isEmpty) ...[
              const Divider(),
              Text(
                _t('orders_usage_builder_empty', 'No deployment records yet.'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const Divider(),
              Text(
                _t('orders_usage_builder_projects_title', 'Top Projects'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...projects.map((project) {
                final emoji = (project.projectEmoji ?? '').trim();
                final prefix = emoji.isEmpty ? '📦' : emoji;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(prefix),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.projectName.isEmpty
                              ? project.projectId
                              : project.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(project.totalBuildSeconds),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '\$${project.estimatedCostUsd.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('orders_usage_time_range', 'Time Range'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // 改为 Row 单行显示
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableMonths.map((months) {
                  final theme = Theme.of(context);
                  final isSelected = _selectedMonths == months;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () async {
                        if (mounted) {
                          setState(() {
                            _selectedMonths = months;
                          });
                        }
                        await _reloadLlmUsage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.35,
                                  ),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _t(
                            'orders_usage_time_range_months',
                            '{months} months',
                          ).replaceAll('{months}', months.toString()),
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectBreakdown() {
    if (_projectUsage.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _t(
                    'orders_usage_project_breakdown_empty',
                    'No usage data available',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'orders_usage_project_breakdown_empty_hint',
                    'Your LLM usage will appear here',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _projectUsage.map((project) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    project.emoji ?? '🧠',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (project.archived) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _t('orders_usage_project_deleted', 'Deleted'),
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.token,
                              size: 14,
                              color: Colors.purple.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(
                                project.totalInputTokens +
                                    project.totalOutputTokens,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.memory,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(project.totalCacheReadTokens),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${project.totalCostUsd.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'in=${project.totalInputTokens.toString()} • out=${project.totalOutputTokens.toString()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
