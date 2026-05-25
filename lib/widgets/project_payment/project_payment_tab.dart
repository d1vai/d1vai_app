import 'package:flutter/material.dart';
import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../models/payment.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../app_menu_button.dart';
import '../adaptive_modal.dart';
import '../project_activation_panel.dart';
import '../select.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - Payment Tab
class ProjectPaymentTab extends StatefulWidget {
  final String projectId;
  final String? projectPayId;
  final Future<void> Function()? onRefreshProject;
  final void Function(String prompt)? onAskAi;

  const ProjectPaymentTab({
    super.key,
    required this.projectId,
    this.projectPayId,
    this.onRefreshProject,
    this.onAskAi,
  });

  @override
  State<ProjectPaymentTab> createState() => _ProjectPaymentTabState();
}

enum _PaymentWorkspaceTab { overview, products, transactions }

class _ProjectPaymentTabState extends State<ProjectPaymentTab> {
  PayMetrics? _payMetrics;
  final List<PayProduct> _payProducts = [];
  final List<PaymentTransaction> _paymentTransactions = [];
  final Set<String> _expandedProductIds = <String>{};
  final Set<String> _expandedTransactionIds = <String>{};
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isActivating = false;
  bool _paymentActivationRequired = false;
  bool _paymentActivatedOverride = false;
  String? _loadError;
  _PaymentWorkspaceTab _activeWorkspaceTab = _PaymentWorkspaceTab.overview;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  ButtonStyle _densePrimaryButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton.styleFrom(
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  ButtonStyle _denseOutlineButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.42)),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _countPill(BuildContext context, String label, {Color? tone}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = tone ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildWorkspaceTabs(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget tab(
      _PaymentWorkspaceTab value,
      IconData icon,
      String label, {
      String? counter,
    }) {
      final active = _activeWorkspaceTab == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _activeWorkspaceTab = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.12),
                      cs.surface,
                    )
                  : cs.surface.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.22)
                    : cs.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: active ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (counter != null && counter.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      counter,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLow.withValues(alpha: 0.72),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          tab(
            _PaymentWorkspaceTab.overview,
            Icons.space_dashboard_outlined,
            _t('project_payment_overview', 'Overview'),
          ),
          const SizedBox(width: 8),
          tab(
            _PaymentWorkspaceTab.products,
            Icons.sell_outlined,
            _t('project_payment_products', 'Payment Products'),
            counter: '${_payProducts.length}',
          ),
          const SizedBox(width: 8),
          tab(
            _PaymentWorkspaceTab.transactions,
            Icons.receipt_long_outlined,
            _t('project_payment_recent_transactions', 'Recent Transactions'),
            counter: '${_paymentTransactions.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activated = _isPaymentActivated;
    final subtitle = activated
        ? 'Manage checkout surfaces, products, and successful orders.'
        : 'Initialize payments before configuring products and transactions.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLow.withValues(alpha: 0.76),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _countPill(
                context,
                activated ? 'ACTIVE' : 'SETUP',
                tone: activated ? Colors.green : cs.primary,
              ),
              if (_payMetrics != null)
                _countPill(
                  context,
                  _payMetrics!.formattedRevenue,
                  tone: cs.tertiary,
                ),
              if (_activeWorkspaceTab == _PaymentWorkspaceTab.products)
                ElevatedButton.icon(
                  onPressed: () => _showAddPayProductDialog(context),
                  style: _densePrimaryButtonStyle(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(_t('project_payment_add', 'Add')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceBody(BuildContext context) {
    return switch (_activeWorkspaceTab) {
      _PaymentWorkspaceTab.overview => _buildOverviewCard(),
      _PaymentWorkspaceTab.products => _buildProductsCard(context),
      _PaymentWorkspaceTab.transactions => _buildTransactionsCard(),
    };
  }

  String _productRowKey(PayProduct product) {
    final id = product.id.trim();
    if (id.isNotEmpty) return id;
    return '${product.name}|${product.price}|${product.createdAt ?? ''}';
  }

  String _transactionRowKey(PaymentTransaction tx) {
    final id = tx.id.trim();
    if (id.isNotEmpty) return id;
    return '${tx.productName ?? ''}|${tx.amount}|${tx.createdAt ?? ''}';
  }

  void _toggleExpanded(Set<String> items, String key) {
    setState(() {
      if (!items.add(key)) {
        items.remove(key);
      }
    });
  }

  String _formatTimestamp(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '—';
    try {
      final dt = DateTime.parse(value).toLocal();
      final date = MaterialLocalizations.of(context).formatMediumDate(dt);
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(dt),
        alwaysUse24HourFormat: true,
      );
      return '$date $time';
    } catch (_) {
      return value;
    }
  }

  void _askAiAboutProduct(PayProduct product) {
    final question = _t(
      'project_payment_ai_prompt_product',
      'Can you analyze the payment product "{name}" and provide suggestions on pricing strategy, configuration, or marketing improvements?',
    ).replaceAll('{name}', product.name);
    widget.onAskAi?.call(question);
  }

  void _askAiAboutTransaction(PaymentTransaction tx) {
    final question = _t(
      'project_payment_ai_prompt_transaction',
      'Can you analyze this payment transaction ({amount}, {status}) and provide insights about payment patterns or recommendations?',
    ).replaceAll('{amount}', tx.formattedAmount).replaceAll('{status}', tx.statusLabel);
    widget.onAskAi?.call(question);
  }

  Widget _buildDetailTile(
    BuildContext context,
    String label,
    String value, {
    bool monospace = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, PayProduct product) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rowKey = _productRowKey(product);
    final expanded = _expandedProductIds.contains(rowKey);
    final description = (product.description ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => _toggleExpanded(_expandedProductIds, rowKey),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.sell_outlined,
                          size: 17,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: expanded ? 4 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _countPill(
                            context,
                            product.isActive ? 'ACTIVE' : 'PAUSED',
                            tone: product.isActive
                                ? Colors.green
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.formattedPrice,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: product.price > 0
                                  ? Colors.green.shade700
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      AppMenuButton<String>(
                        tooltip: _t('more', 'More'),
                        actions: [
                          AppMenuAction(
                            value: 'edit',
                            label: _t('project_payment_edit', 'Edit'),
                            icon: Icons.edit,
                          ),
                          AppMenuAction(
                            value: 'link',
                            label: _t('project_payment_get_link', 'Get Link'),
                            icon: Icons.link,
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditPayProductDialog(context, product);
                          } else if (value == 'link') {
                            SnackBarHelper.showInfo(
                              context,
                              title: _t('project_payment_link', 'Payment Link'),
                              message: _t(
                                'project_payment_getting_link',
                                'Getting payment link...',
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDetailTile(
                          context,
                          'Product ID',
                          product.id.trim().isEmpty ? '—' : product.id.trim(),
                          monospace: true,
                        ),
                        _buildDetailTile(context, 'Currency', product.currency),
                        _buildDetailTile(
                          context,
                          'Created',
                          _formatTimestamp(product.createdAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _askAiAboutProduct(product),
                          style: _denseOutlineButtonStyle(context),
                          icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                          ),
                          label: const Text('Ask AI'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showEditPayProductDialog(context, product),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(_t('project_payment_edit', 'Edit')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, PaymentTransaction tx) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rowKey = _transactionRowKey(tx);
    final expanded = _expandedTransactionIds.contains(rowKey);
    final customer = (tx.customerEmail ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => _toggleExpanded(_expandedTransactionIds, rowKey),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tx.statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          tx.statusIcon,
                          size: 17,
                          color: tx.statusColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.productName ??
                                  _t(
                                    'project_payment_unknown_product',
                                    'Unknown Product',
                                  ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer.isEmpty
                                  ? _t('project_payment_anonymous', 'Anonymous')
                                  : customer,
                              maxLines: expanded ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
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
                            tx.formattedAmount,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _countPill(
                            context,
                            tx.statusLabel.toUpperCase(),
                            tone: tx.statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDetailTile(
                          context,
                          'Transaction ID',
                          tx.id.trim().isEmpty ? '—' : tx.id.trim(),
                          monospace: true,
                        ),
                        _buildDetailTile(
                          context,
                          'Payment method',
                          (tx.paymentMethod ?? '').trim().isEmpty
                              ? '—'
                              : tx.paymentMethod!.trim(),
                        ),
                        _buildDetailTile(
                          context,
                          'Created',
                          _formatTimestamp(tx.createdAt),
                        ),
                        _buildDetailTile(
                          context,
                          'Completed',
                          _formatTimestamp(tx.completedAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _askAiAboutTransaction(tx),
                      style: _denseOutlineButtonStyle(context),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: const Text('Ask AI'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadPaymentData();
    }
  }

  @override
  void didUpdateWidget(covariant ProjectPaymentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _expandedProductIds.clear();
      _expandedTransactionIds.clear();
      _activeWorkspaceTab = _PaymentWorkspaceTab.overview;
      if (_isInitialized && !_isLoading) {
        unawaited(_loadPaymentData());
      }
      return;
    }
    if (oldWidget.projectPayId != widget.projectPayId &&
        widget.projectPayId != null) {
      _paymentActivationRequired = false;
      _paymentActivatedOverride = false;
      if (_isInitialized && !_isLoading) {
        unawaited(_loadPaymentData());
      }
    }
  }

  bool get _isPaymentActivated =>
      _paymentActivatedOverride ||
      (widget.projectPayId != null && widget.projectPayId!.trim().isNotEmpty);

  bool _isPaymentNotActivatedError(String message) {
    final normalized = message.toLowerCase();
    return (normalized.contains('404') ||
            normalized.contains('not found') ||
            normalized.contains('not activated')) &&
        (normalized.contains('project pay') ||
            normalized.contains('payment integration') ||
            normalized.contains('activate-pay') ||
            normalized.contains('pay integration'));
  }

  Future<void> _loadPaymentData() async {
    if (!_isPaymentActivated && !_paymentActivatedOverride) {
      setState(() {
        _isLoading = false;
        _loadError = null;
        _paymentActivationRequired = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
      _paymentActivationRequired = false;
    });

    try {
      final service = D1vaiService();

      final results = await Future.wait([
        service.getPayDashboardMetrics(widget.projectId, days: '30'),
        service.getPayProducts(widget.projectId),
        service.getPayTransactions(widget.projectId, status: 'success'),
      ]);

      final metricsData = results[0] as Map<String, dynamic>;
      final productsData = results[1] as List<dynamic>;
      final transactionsData = results[2] as List<dynamic>;

      final metrics = PayMetrics.fromJson(metricsData);
      final products = productsData
          .map((item) => PayProduct.fromJson(item))
          .toList();
      final transactions = transactionsData
          .map((item) => PaymentTransaction.fromJson(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _payMetrics = metrics;
        _payProducts
          ..clear()
          ..addAll(products);
        _paymentTransactions
          ..clear()
          ..addAll(transactions);
        _isLoading = false;
        _loadError = null;
        _paymentActivationRequired = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
      if (_isPaymentNotActivatedError(msg)) {
        setState(() {
          _isLoading = false;
          _loadError = null;
          _paymentActivationRequired = true;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = msg;
      });
      final authExpired = isAuthExpiredText(msg);
      if (authExpired) {
        AuthExpiryBus.trigger(
          endpoint: '/api/projects/${widget.projectId}/payment',
        );
        return;
      }
      SnackBarHelper.showError(
        context,
        title: _t('project_payment_load_failed', 'Load failed'),
        message: msg,
      );
    }
  }

  Future<void> _activatePayments() async {
    setState(() {
      _isActivating = true;
    });
    try {
      final service = D1vaiService();
      await service.activateProjectPay(widget.projectId);
      if (!mounted) return;
      setState(() {
        _paymentActivatedOverride = true;
        _paymentActivationRequired = false;
      });
      SnackBarHelper.showSuccess(
        context,
        title: _t('project_payment_enable_title', 'Enable payments'),
        message: _t(
          'project_payment_enable_success',
          'Payments activated successfully',
        ),
      );
      await widget.onRefreshProject?.call();
      await _loadPaymentData();
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_payment_enable_title', 'Enable payments'),
        message:
            '${_t('project_payment_enable_failed', 'Failed to activate payments')}: ${humanizeError(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentActivationRequired) {
      return _buildActivatePaymentsState();
    }

    final error = _loadError;
    if (error != null && error.trim().isNotEmpty) {
      final authExpired = isAuthExpiredText(error);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadPaymentData,
                    style: _densePrimaryButtonStyle(context),
                    icon: const Icon(Icons.refresh),
                    label: Text(_t('retry', 'Retry')),
                  ),
                  if (authExpired)
                    OutlinedButton.icon(
                      onPressed: () {
                        AuthExpiryBus.trigger(
                          endpoint: '/api/projects/${widget.projectId}/payment',
                        );
                      },
                      style: _denseOutlineButtonStyle(context),
                      icon: const Icon(Icons.login),
                      label: Text(_t('project_payment_relogin', 'Re-login')),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWorkspaceHeader(context),
            const SizedBox(height: 12),
            _buildWorkspaceTabs(context),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_activeWorkspaceTab),
                child: _buildWorkspaceBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivatePaymentsState() {
    final theme = Theme.of(context);
    return ProjectActivationPanel(
      icon: Icons.credit_score_rounded,
      title: _t('project_payment_enable_title', 'Enable payments'),
      description: _t(
        'project_payment_enable_description',
        'Payments are not activated for this project yet. Initialize payments first, then manage products, transactions, bank accounts, withdrawals, and webhooks.',
      ),
      features: [
        _t(
          'project_payment_enable_feature_checkout',
          'Stripe checkout and payment links',
        ),
        _t(
          'project_payment_enable_feature_products',
          'Products, balances, and withdrawals',
        ),
        _t(
          'project_payment_enable_feature_webhooks',
          'Webhook-ready order lifecycle',
        ),
      ],
      actionLabel: _isActivating
          ? _t('project_payment_enable_loading', 'Initializing…')
          : _t('project_payment_enable_button', 'Enable Payments'),
      isLoading: _isActivating,
      onPressed: _activatePayments,
      accentColor: theme.colorScheme.tertiary,
    );
  }

  Widget _buildOverviewCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final metricWidth = wide
                ? (constraints.maxWidth - 30) / 4
                : (constraints.maxWidth - 10) / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('project_payment_overview', 'Payment Overview'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _countPill(context, '30D'),
                  ],
                ),
                const SizedBox(height: 10),
                if (_payMetrics != null)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: metricWidth,
                        child: _PayMetricCard(
                          title: _t(
                            'project_payment_total_revenue',
                            'Total Revenue',
                          ),
                          value: _payMetrics!.formattedRevenue,
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _PayMetricCard(
                          title: _t(
                            'project_payment_transactions',
                            'Transactions',
                          ),
                          value: _payMetrics!.totalTransactions.toString(),
                          icon: Icons.receipt_long_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _PayMetricCard(
                          title: _t(
                            'project_payment_conversion_rate',
                            'Conversion Rate',
                          ),
                          value: _payMetrics!.formattedConversionRate,
                          icon: Icons.trending_up_rounded,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _PayMetricCard(
                          title: _t(
                            'project_payment_active_customers',
                            'Active Customers',
                          ),
                          value: _payMetrics!.activeCustomers.toString(),
                          icon: Icons.people_outline_rounded,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _t(
                      'project_payment_not_activated',
                      'Payment not activated yet',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        _t('project_payment_products', 'Payment Products'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_payProducts.length} configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _countPill(
                  context,
                  '${_payProducts.length}',
                  tone: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_payProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _t('project_payment_no_products', 'No payment products yet'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._payProducts.map(
                (product) => _buildProductRow(context, product),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        _t(
                          'project_payment_recent_transactions',
                          'Recent Transactions',
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Latest successful checkouts',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _countPill(
                  context,
                  '${_paymentTransactions.length}',
                  tone: theme.colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_paymentTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _t('project_payment_no_transactions', 'No transactions yet'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._paymentTransactions
                  .take(5)
                  .map((tx) => _buildTransactionRow(context, tx)),
          ],
        ),
      ),
    );
  }

  void _showAddPayProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCurrency = 'USD';
    bool isActive = true;
    String error = '';
    bool isLoading = false;

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 540,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: _t(
                    'project_payment_add_product_title',
                    'Add Payment Product',
                  ),
                  subtitle: _t(
                    'project_payment_description_hint',
                    'Describe your product',
                  ),
                  onClose: isLoading ? null : () => Navigator.pop(context),
                ),
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _t(
                      'project_payment_product_name',
                      'Product Name',
                    ),
                    hintText: _t(
                      'project_payment_product_name_hint',
                      'e.g., Premium Plan',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: _t(
                      'project_payment_description_optional',
                      'Description (Optional)',
                    ),
                    hintText: _t(
                      'project_payment_description_hint',
                      'Describe your product',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration: InputDecoration(
                          labelText: _t('project_payment_price', 'Price'),
                          hintText: '0.00',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Select<String>(
                        value: selectedCurrency,
                        items: const [
                          SelectItem(value: 'USD', child: Text('USD')),
                          SelectItem(value: 'EUR', child: Text('EUR')),
                          SelectItem(value: 'GBP', child: Text('GBP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCurrency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(_t('project_payment_active', 'Active')),
                  subtitle: Text(
                    _t(
                      'project_payment_available_for_purchase',
                      'Product is available for purchase',
                    ),
                  ),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(_t('cancel', 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final description = descriptionController.text
                                    .trim();
                                final priceText = priceController.text.trim();

                                if (name.isEmpty) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_product_name_required',
                                      'Product name is required',
                                    );
                                  });
                                  return;
                                }

                                if (priceText.isEmpty) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_price_required',
                                      'Price is required',
                                    );
                                  });
                                  return;
                                }

                                final price = double.tryParse(priceText);
                                if (price == null || price <= 0) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_price_invalid',
                                      'Please enter a valid price',
                                    );
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                  error = '';
                                });

                                try {
                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  );

                                  if (!mounted) return;

                                  final product = PayProduct(
                                    id: DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                    name: name,
                                    description: description.isEmpty
                                        ? null
                                        : description,
                                    price: price,
                                    currency: selectedCurrency,
                                    isActive: isActive,
                                    createdAt: DateTime.now().toIso8601String(),
                                  );

                                  setState(() {
                                    _payProducts.add(product);
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    isLoading = false;
                                    error = _t(
                                      'project_payment_add_product_failed',
                                      'Failed to add product: {error}',
                                    ).replaceAll('{error}', '$e');
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _t(
                                  'project_payment_add_product',
                                  'Add Product',
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
      ),
    );
  }

  void _showEditPayProductDialog(BuildContext context, PayProduct product) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(
      text: product.description ?? '',
    );
    final priceController = TextEditingController(
      text: product.price.toString(),
    );
    String selectedCurrency = product.currency;
    bool isActive = product.isActive;
    String error = '';
    bool isLoading = false;

    showAdaptiveModal(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AdaptiveModalContainer(
          maxWidth: 540,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveModalHeader(
                  title: _t(
                    'project_payment_edit_product_title',
                    'Edit Payment Product',
                  ),
                  subtitle: _t(
                    'project_payment_description_hint',
                    'Describe your product',
                  ),
                  onClose: isLoading ? null : () => Navigator.pop(context),
                ),
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _t(
                      'project_payment_product_name',
                      'Product Name',
                    ),
                    hintText: _t(
                      'project_payment_product_name_hint',
                      'e.g., Premium Plan',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: _t(
                      'project_payment_description_optional',
                      'Description (Optional)',
                    ),
                    hintText: _t(
                      'project_payment_description_hint',
                      'Describe your product',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration: InputDecoration(
                          labelText: _t('project_payment_price', 'Price'),
                          hintText: '0.00',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Select<String>(
                        value: selectedCurrency,
                        items: const [
                          SelectItem(value: 'USD', child: Text('USD')),
                          SelectItem(value: 'EUR', child: Text('EUR')),
                          SelectItem(value: 'GBP', child: Text('GBP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCurrency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(_t('project_payment_active', 'Active')),
                  subtitle: Text(
                    _t(
                      'project_payment_available_for_purchase',
                      'Product is available for purchase',
                    ),
                  ),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(_t('cancel', 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final description = descriptionController.text
                                    .trim();
                                final priceText = priceController.text.trim();

                                if (name.isEmpty) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_product_name_required',
                                      'Product name is required',
                                    );
                                  });
                                  return;
                                }

                                if (priceText.isEmpty) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_price_required',
                                      'Price is required',
                                    );
                                  });
                                  return;
                                }

                                final price = double.tryParse(priceText);
                                if (price == null || price <= 0) {
                                  setDialogState(() {
                                    error = _t(
                                      'project_payment_price_invalid',
                                      'Please enter a valid price',
                                    );
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                  error = '';
                                });

                                try {
                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  );

                                  if (!mounted) return;

                                  setState(() {
                                    final index = _payProducts.indexOf(product);
                                    if (index != -1) {
                                      _payProducts[index] = PayProduct(
                                        id: product.id,
                                        name: name,
                                        description: description.isEmpty
                                            ? null
                                            : description,
                                        price: price,
                                        currency: selectedCurrency,
                                        isActive: isActive,
                                        createdAt: product.createdAt,
                                      );
                                    }
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    isLoading = false;
                                    error = _t(
                                      'project_payment_update_product_failed',
                                      'Failed to update product: {error}',
                                    ).replaceAll('{error}', '$e');
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _t(
                                  'project_payment_save_changes',
                                  'Save Changes',
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
      ),
    );
  }
}

class _PayMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PayMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
