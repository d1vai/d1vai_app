import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallet_service.dart';

/// Animated CountUp widget for dollar amounts
class CountUp extends StatefulWidget {
  final double value;
  final Duration duration;
  final TextStyle? style;

  const CountUp({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 900),
    this.style,
  });

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _animateToValue();
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animateToValue();
    }
  }

  void _animateToValue() {
    setState(() {
      _currentValue = 0.0;
    });

    final startTime = DateTime.now();
    final duration = widget.duration;

    void updateValue() {
      final elapsed = DateTime.now().difference(startTime);
      final progress = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

      setState(() {
        _currentValue = widget.value * progress;
      });

      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), updateValue);
      }
    }

    updateValue();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentValue.toStringAsFixed(2),
      style: widget.style,
    );
  }
}

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
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  List<CreditHistoryItem> _credits = [];
  Set<String> _newCreditIds = {};
  Map<String, double>? _arrivalBanner;

  @override
  void initState() {
    super.initState();
    _loadCreditHistory();
  }

  Future<void> _loadCreditHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final creditIssuances = await _walletService.getCreditIssuances(limit: 50);

      // Get last seen timestamp from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastSeenMillis = prefs.getInt('last_seen_credit_timestamp') ?? 0;

      // Convert CreditIssuance to CreditHistoryItem
      final now = DateTime.now();
      final List<CreditHistoryItem> credits = [];
      final Set<String> newIds = {};
      double bannerSum = 0.0;

      for (final issuance in creditIssuances) {
        final issuedAt = DateTime.parse(issuance.issuedAt);
        final expiresAt = issuance.expiresAt != null
            ? DateTime.parse(issuance.expiresAt!)
            : null;
        final issuedAtMillis = issuedAt.millisecondsSinceEpoch;

        // Determine if credit is expiring (expires within 90 days or already expired)
        bool isExpiring = false;
        if (expiresAt != null) {
          final daysUntilExpiry = expiresAt.difference(now).inDays;
          isExpiring = daysUntilExpiry <= 90;
        }

        // Check if credit is new (issued after last seen timestamp)
        bool isNew = issuedAtMillis > lastSeenMillis;

        final item = CreditHistoryItem(
          id: issuance.id,
          amount: issuance.amountUsd,
          source: issuance.source ?? 'unknown',
          issuedAt: issuedAt,
          expiresAt: expiresAt,
          isExpiring: isExpiring,
          isNew: isNew,
        );

        credits.add(item);

        // Track new credits for banner
        if (isNew && issuedAtMillis > 0) {
          newIds.add(issuance.id);
          bannerSum += issuance.amountUsd;
        }
      }

      // Sort by issued date (newest first)
      credits.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

      // Update state
      setState(() {
        _credits = credits;
        _newCreditIds = newIds;
        _isLoading = false;
      });

      // Show banner if new credits detected
      if (newIds.isNotEmpty) {
        setState(() {
          _arrivalBanner = {'sum': bannerSum};
        });

        // Update last seen timestamp
        final maxIssuedMillis = credits
            .map((c) => c.issuedAt.millisecondsSinceEpoch)
            .fold<int>(0, (max, val) => val > max ? val : max);
        await prefs.setInt('last_seen_credit_timestamp', maxIssuedMillis);

        // Auto-hide banner after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _arrivalBanner = null;
            });
          }
        });

        // Clear new highlight after banner disappears
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _newCreditIds = {};
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load credit history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load credit history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    return Column(
      children: [
        // Credit arrival banner
        if (_arrivalBanner != null) _buildArrivalBanner(_arrivalBanner!),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCreditHistory,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _credits.length,
              itemBuilder: (context, index) {
                final credit = _credits[index];
                return _buildCreditCard(credit);
              },
            ),
          ),
        ),
      ],
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

  Widget _buildArrivalBanner(Map<String, double> banner) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.shade50,
        border: Border.all(
          color: Colors.green.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Funds received',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '+ \$',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Expanded(
                      child: CountUp(
                        value: banner['sum'] ?? 0,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.green.shade600,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _arrivalBanner = null;
              });
            },
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(CreditHistoryItem credit) {
    final isHighlighted = _newCreditIds.contains(credit.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: Colors.green.shade400,
                width: 2,
              )
            : null,
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.green.shade200.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isHighlighted ? 2 : 1,
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
                      color: isHighlighted ? Colors.green.shade800 : Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '+ \$',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isHighlighted ? Colors.green.shade800 : Colors.green.shade600,
                              ),
                            ),
                            if (isHighlighted)
                              Expanded(
                                child: CountUp(
                                  value: credit.amount,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              )
                            else
                              Text(
                                credit.amount.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            if (isHighlighted)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'credited',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
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
