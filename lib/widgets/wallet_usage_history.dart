import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/balance.dart';
import '../services/wallet_service.dart';
import 'skeletons/credit_history_skeleton.dart';
import 'snackbar_helper.dart';

class WalletUsageHistory extends StatefulWidget {
  const WalletUsageHistory({super.key});

  @override
  State<WalletUsageHistory> createState() => _WalletUsageHistoryState();
}

class _WalletUsageHistoryState extends State<WalletUsageHistory> {
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  List<CreditIssuance> _records = const <CreditIssuance>[];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rows = await _walletService.getCreditIssuances(
        limit: 50,
        direction: 'debit',
      );
      final records =
          rows.where((it) => it.direction.toLowerCase() == 'debit').toList()
            ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SnackBarHelper.showError(
        context,
        title: _t('error', 'Error'),
        message: e.toString(),
      );
    }
  }

  String _t(String key, String fallback) =>
      AppLocalizations.of(context)?.translate(key) ?? fallback;

  ({String label, String detail}) _parseSource(String? source) {
    final raw = (source ?? '').trim();
    if (raw.isEmpty) {
      return (label: '-', detail: '');
    }
    final parts = raw.split(':');
    final kind = parts.first.trim();
    final detail = parts.skip(1).join(':').trim();
    if (kind == 'admin_broadcast') {
      final template = _t(
        'orders_wallet_usage_source_system_message',
        'System message: {description}',
      );
      return (
        label: _t(
          'orders_wallet_usage_source_admin_broadcast',
          'admin broadcast',
        ),
        detail: detail.isEmpty
            ? ''
            : template.replaceAll('{description}', detail),
      );
    }
    final normalized = kind
        .replaceAll('_', ' ')
        .replaceAll('admin invite', 'onboarding');
    return (label: normalized, detail: '');
  }

  String _bucketLabel(String? bucket) {
    if ((bucket ?? '').toLowerCase() == 'expiring') {
      return _t('orders_wallet_usage_bucket_expiring', 'Expiring');
    }
    return _t('orders_wallet_usage_bucket_non_expiring', 'Non-expiring');
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CreditHistorySkeleton();
    }
    if (_records.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildRowCard(_records[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              _t('orders_wallet_usage_empty', 'No usage records yet.'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'orders_wallet_usage_empty_hint',
                'Consumption records from deployments and model usage will appear here.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowCard(CreditIssuance item) {
    final source = _parseSource(item.source);
    final amount = item.amountUsd.abs().toStringAsFixed(2);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '- \$$amount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _bucketLabel(item.bucket),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(item.issuedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              source.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (source.detail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                source.detail,
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
}
