import 'package:flutter/material.dart';
import '../models/payment.dart';
import 'order_detail_dialog.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
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

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 1000));

    // Mock data - in real implementation, fetch from API
    final mockOrders = [
      PaymentTransaction(
        id: 'TXN-2024-001',
        productId: 'PRO-PLAN-PRO',
        productName: 'Professional Plan',
        amount: 99.00,
        currency: 'USD',
        status: 'succeeded',
        customerEmail: 'user@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        completedAt: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        paymentMethod: 'stripe',
      ),
      PaymentTransaction(
        id: 'TXN-2024-002',
        productId: 'TOP-50',
        productName: 'Top-up Credits',
        amount: 50.00,
        currency: 'USD',
        status: 'succeeded',
        customerEmail: 'user@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        completedAt: DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        paymentMethod: 'stripe',
      ),
      PaymentTransaction(
        id: 'TXN-2024-003',
        productId: 'PRO-PLAN-BASIC',
        productName: 'Basic Plan',
        amount: 29.00,
        currency: 'USD',
        status: 'succeeded',
        customerEmail: 'user@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        completedAt: DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        paymentMethod: 'stripe',
      ),
      PaymentTransaction(
        id: 'TXN-2024-004',
        productId: 'TOP-25',
        productName: 'Top-up Credits',
        amount: 25.00,
        currency: 'USD',
        status: 'pending',
        customerEmail: 'user@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        paymentMethod: 'stripe',
      ),
      PaymentTransaction(
        id: 'TXN-2024-005',
        productId: 'TOP-100',
        productName: 'Top-up Credits',
        amount: 100.00,
        currency: 'USD',
        status: 'failed',
        customerEmail: 'user@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        paymentMethod: 'stripe',
      ),
    ];

    setState(() {
      _orders = mockOrders;
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

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
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
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your purchase history will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(PaymentTransaction order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => OrderDetailDialog(order: order),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          order.productName ?? 'Unknown Product',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order ID: ${order.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        order.formattedAmount,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusChip(order.status),
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
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Created: ${_formatDate(order.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (order.paymentMethod != null) ...[
                    Icon(
                      Icons.credit_card,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.paymentMethod!.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'success':
      case 'succeeded':
      case 'paid':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Completed';
        break;
      case 'pending':
      case 'processing':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        label = 'Pending';
        break;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Failed';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
