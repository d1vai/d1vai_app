import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment.dart';
import 'adaptive_modal.dart';

/// 订单详情对话框
class OrderDetailDialog extends StatefulWidget {
  final PaymentTransaction order;

  const OrderDetailDialog({super.key, required this.order});

  static Future<T?> show<T>(
    BuildContext context, {
    required PaymentTransaction order,
  }) {
    return showAdaptiveModal<T>(
      context: context,
      builder: (context) => OrderDetailDialog(order: order),
    );
  }

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  Future<void> _downloadInvoice() async {
    if (!mounted) return;

    final invoiceUrl = 'https://billing.d1v.ai/invoices/${widget.order.id}.pdf';
    final uri = Uri.tryParse(invoiceUrl);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);

    if (mounted && canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not download invoice')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AdaptiveModalContainer(
      maxWidth: 720,
      mobileMaxHeightFactor: 0.98,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveModalHeader(
            title: 'Order Details',
            subtitle: 'Transaction ID: ${order.id}',
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: order.statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(order.statusIcon, color: order.statusColor, size: 22),
            ),
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(order),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Order Information',
                    children: [
                      _buildInfoRow(
                        'Product',
                        order.productName ?? 'N/A',
                        icon: Icons.inventory_2,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Amount',
                        order.formattedAmount,
                        icon: Icons.attach_money,
                        valueColor: colorScheme.primary,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Currency',
                        order.currency.toUpperCase(),
                        icon: Icons.currency_exchange,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Payment Method',
                        order.paymentMethod?.toUpperCase() ?? 'N/A',
                        icon: Icons.payment,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Timestamps',
                    children: [
                      _buildInfoRow(
                        'Created',
                        _formatDateTime(order.createdAt),
                        icon: Icons.schedule,
                      ),
                      if (order.completedAt != null) ...[
                        const Divider(),
                        _buildInfoRow(
                          'Completed',
                          _formatDateTime(order.completedAt),
                          icon: Icons.check_circle,
                        ),
                      ],
                    ],
                  ),
                  if (order.customerEmail != null) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Customer',
                      children: [
                        _buildInfoRow(
                          'Email',
                          order.customerEmail!,
                          icon: Icons.email,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: colorScheme.outline),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadInvoice,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    icon: const Icon(Icons.file_download, size: 20),
                    label: const Text('Invoice'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(PaymentTransaction order) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: order.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: order.statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(order.statusIcon, color: order.statusColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${order.statusLabel}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: order.statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment Status: ${order.status}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
