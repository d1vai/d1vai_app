import 'package:flutter/material.dart';

class UsageStats extends StatefulWidget {
  const UsageStats({super.key});

  @override
  State<UsageStats> createState() => _UsageStatsState();
}

class _UsageStatsState extends State<UsageStats> {
  bool _isLoading = true;

  // Mock data for database usage
  double _databaseStorage = 0.0;
  int _databaseQueries = 0;
  int _databaseConnections = 0;

  // Mock data for LLM usage
  int _llmTokens = 0;
  int _llmRequests = 0;
  double _llmCost = 0.0;

  // Mock data for project breakdown
  List<Map<String, dynamic>> _projectUsage = [];

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 1000));

    // Mock data - in real implementation, fetch from API
    setState(() {
      _databaseStorage = 2.4; // GB
      _databaseQueries = 1247; // Total queries
      _databaseConnections = 12; // Active connections

      _llmTokens = 125430; // Total tokens
      _llmRequests = 156; // Total requests
      _llmCost = 4.82; // USD

      // Mock project usage data
      _projectUsage = [
        {
          'name': 'E-commerce App',
          'emoji': '🛒',
          'databaseStorage': 1.2,
          'llmTokens': 45000,
          'llmRequests': 68,
          'llmCost': 2.15,
        },
        {
          'name': 'AI Chatbot',
          'emoji': '🤖',
          'databaseStorage': 0.8,
          'llmTokens': 52300,
          'llmRequests': 54,
          'llmCost': 1.82,
        },
        {
          'name': 'Analytics Dashboard',
          'emoji': '📊',
          'databaseStorage': 0.4,
          'llmTokens': 28130,
          'llmRequests': 34,
          'llmCost': 0.85,
        },
      ];

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsageStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Database Usage'),
          const SizedBox(height: 12),
          _buildDatabaseStatsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('LLM Usage'),
          const SizedBox(height: 12),
          _buildLLMStatsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Project Breakdown'),
          const SizedBox(height: 12),
          _buildProjectBreakdown(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Icon(
          Icons.analytics,
          color: Colors.deepPurple,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow(
              icon: Icons.storage,
              label: 'Storage Used',
              value: '${_databaseStorage.toStringAsFixed(1)} GB',
              color: Colors.blue,
              subtitle: 'of 10 GB limit',
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.search,
              label: 'Total Queries',
              value: _databaseQueries.toString(),
              color: Colors.green,
              subtitle: 'this month',
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.link,
              label: 'Active Connections',
              value: _databaseConnections.toString(),
              color: Colors.orange,
              subtitle: 'currently active',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLLMStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow(
              icon: Icons.token,
              label: 'Tokens Consumed',
              value: _formatNumber(_llmTokens),
              color: Colors.purple,
              subtitle: 'total tokens',
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.send,
              label: 'API Requests',
              value: _llmRequests.toString(),
              color: Colors.teal,
              subtitle: 'this month',
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.attach_money,
              label: 'Total Cost',
              value: '\$${_llmCost.toStringAsFixed(2)}',
              color: Colors.red,
              subtitle: 'estimated cost',
            ),
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
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
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

  Widget _buildProjectBreakdown() {
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
                    project['emoji'],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project['name'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${project['databaseStorage']} GB',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.token,
                              size: 14,
                              color: Colors.purple.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(project['llmTokens']),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
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
                        '\$${project['llmCost'].toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${project['llmRequests']} requests',
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
