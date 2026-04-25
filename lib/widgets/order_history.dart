import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../services/wallet_service.dart';
import 'order_detail_dialog.dart';
import 'snackbar_helper.dart';
import 'card.dart';
import 'skeletons/order_history_skeleton.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  List<PaymentTransaction> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _walletService.getTransactions(limit: 50);
      if (!mounted) return;

      // Sort by created date (newest first)
      orders.sort((a, b) {
        final aDate = a.createdAt ?? '';
        final bDate = b.createdAt ?? '';
        return bDate.compareTo(aDate);
      });

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message
        SnackBarHelper.showError(
          context,
          title: 'Failed to load orders',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const OrderHistorySkeleton();
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.receipt_long,
                size: 32,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style:
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ) ??
                  const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your purchase history will appear here',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                    height: 1.25,
                  ) ??
                  TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                    height: 1.25,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(PaymentTransaction order) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            OrderDetailDialog.show(context, order: order);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName ?? 'Unknown Product',
                            style:
                                theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order ID: ${order.id}',
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ) ??
                                TextStyle(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          order.formattedAmount,
                          style:
                              theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                              ) ??
                              TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusChip(order.status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Created: ${_formatDate(order.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (order.paymentMethod != null) ...[
                      Icon(
                        Icons.credit_card,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.paymentMethod!.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color color;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'success':
      case 'succeeded':
      case 'paid':
        color = colorScheme.tertiary;
        icon = Icons.check_circle_outline;
        label = 'Completed';
        break;
      case 'pending':
      case 'processing':
        color = colorScheme.secondary;
        icon = Icons.hourglass_empty_rounded;
        label = 'Pending';
        break;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        color = colorScheme.error;
        icon = Icons.cancel_outlined;
        label = 'Failed';
        break;
      default:
        color = colorScheme.onSurfaceVariant;
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.14),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.28),
            colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
