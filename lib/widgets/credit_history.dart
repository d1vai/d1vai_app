import 'package:flutter/material.dart';

class CreditHistory extends StatefulWidget {
  const CreditHistory({super.key});

  @override
  State<CreditHistory> createState() => _CreditHistoryState();
}

class CreditHistoryItem {
  final String id;
  final double amount;
  final String source;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isExpiring;
  final bool isNew;

  CreditHistoryItem({
    required this.id,
    required this.amount,
    required this.source,
    required this.issuedAt,
    this.expiresAt,
    required this.isExpiring,
    this.isNew = false,
  });
}

class _CreditHistoryState extends State<CreditHistory> {
  bool _isLoading = true;
  List<CreditHistoryItem> _credits = [];

  @override
  void initState() {
    super.initState();
    _loadCreditHistory();
  }

  Future<void> _loadCreditHistory() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 1000));

    // Mock data - in real implementation, fetch from API
    final mockCredits = [
      CreditHistoryItem(
        id: 'CR-2024-001',
        amount: 50.00,
        source: 'topup',
        issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isExpiring: false,
        isNew: true,
      ),
      CreditHistoryItem(
        id: 'CR-2024-002',
        amount: 100.00,
        source: 'onboarding',
        issuedAt: DateTime.now().subtract(const Duration(days: 5)),
        isExpiring: false,
        isNew: false,
      ),
      CreditHistoryItem(
        id: 'CR-2024-003',
        amount: 25.00,
        source: 'admin_invite',
        issuedAt: DateTime.now().subtract(const Duration(days: 10)),
        isExpiring: true,
        expiresAt: DateTime.now().add(const Duration(days: 80)),
        isNew: false,
      ),
      CreditHistoryItem(
        id: 'CR-2024-004',
        amount: 25.00,
        source: 'topup',
        issuedAt: DateTime.now().subtract(const Duration(days: 15)),
        isExpiring: true,
        expiresAt: DateTime.now().add(const Duration(days: 75)),
        isNew: false,
      ),
    ];

    setState(() {
      _credits = mockCredits;
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

    if (_credits.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCreditHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _credits.length,
        itemBuilder: (context, index) {
          final credit = _credits[index];
          return _buildCreditCard(credit);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.wallet,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No credit records yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Credits can be obtained through top-ups, onboarding bonuses, or admin invites',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.shade200,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle,
                        size: 20,
                        color: Colors.deepPurple.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Go to Balance tab to top up',
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch to the Balance tab to add funds to your account',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
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

  Widget _buildCreditCard(CreditHistoryItem credit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: credit.isNew ? Colors.green.shade700 : Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${credit.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: credit.isNew ? Colors.green.shade700 : Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              credit.isExpiring ? 'Expiring' : 'Non-expiring',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (credit.isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(color: Colors.amber.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
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
                      _formatDate(credit.issuedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(credit.issuedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Source: ${_formatSource(credit.source)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (credit.expiresAt != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expires: ${_formatDate(credit.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSource(String source) {
    switch (source) {
      case 'topup':
        return 'Top-up';
      case 'admin_invite':
        return 'Admin Invite';
      case 'onboarding':
        return 'Onboarding';
      default:
        return source.replaceAll('_', ' ');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
