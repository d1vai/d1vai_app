import 'package:flutter/material.dart';
import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../models/payment.dart';
import '../../services/d1vai_service.dart';
import '../../core/auth_expiry_bus.dart';
import '../../utils/error_utils.dart';
import '../adaptive_modal.dart';
import '../select.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - Payment Tab
class ProjectPaymentTab extends StatefulWidget {
  final String projectId;
  final void Function(String prompt)? onAskAi;

  const ProjectPaymentTab({super.key, required this.projectId, this.onAskAi});

  @override
  State<ProjectPaymentTab> createState() => _ProjectPaymentTabState();
}

class _ProjectPaymentTabState extends State<ProjectPaymentTab> {
  PayMetrics? _payMetrics;
  final List<PayProduct> _payProducts = [];
  final List<PaymentTransaction> _paymentTransactions = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _loadError;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    if (value == null || value == key) return fallback;
    return value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadPaymentData();
    }
  }

  Future<void> _loadPaymentData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
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
      });
    } catch (e) {
      if (!mounted) return;
      final msg = humanizeError(e);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildProductsCard(context),
            const SizedBox(height: 16),
            _buildTransactionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('project_payment_overview', 'Payment Overview'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (_payMetrics != null) ...[
              Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMetricCard(
                      title: _t('project_payment_transactions', 'Transactions'),
                      value: _payMetrics!.totalTransactions.toString(),
                      icon: Icons.receipt,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PayMetricCard(
                      title: _t(
                        'project_payment_conversion_rate',
                        'Conversion Rate',
                      ),
                      value: _payMetrics!.formattedConversionRate,
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMetricCard(
                      title: _t(
                        'project_payment_active_customers',
                        'Active Customers',
                      ),
                      value: _payMetrics!.activeCustomers.toString(),
                      icon: Icons.people,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ] else
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
        ),
      ),
    );
  }

  Widget _buildProductsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _t('project_payment_products', 'Payment Products'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddPayProductDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _t('project_payment_add', 'Add'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              ..._payProducts.map((product) {
                return InkWell(
                  onTap: () {
                    final question = _t(
                      'project_payment_ai_prompt_product',
                      'Can you analyze the payment product "{name}" and provide suggestions on pricing strategy, configuration, or marketing improvements?',
                    ).replaceAll('{name}', product.name);
                    widget.onAskAi?.call(question);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (product.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  product.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          product.formattedPrice,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: product.price > 0
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_t('project_payment_edit', 'Edit')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'link',
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t('project_payment_get_link', 'Get Link'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditPayProductDialog(context, product);
                            } else if (value == 'link') {
                              SnackBarHelper.showInfo(
                                context,
                                title: _t(
                                  'project_payment_link',
                                  'Payment Link',
                                ),
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
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsCard() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _t(
                    'project_payment_recent_transactions',
                    'Recent Transactions',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_paymentTransactions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              ..._paymentTransactions.take(5).map((tx) {
                return InkWell(
                  onTap: () {
                    final question =
                        _t(
                              'project_payment_ai_prompt_transaction',
                              'Can you analyze this payment transaction ({amount}, {status}) and provide insights about payment patterns or recommendations?',
                            )
                            .replaceAll('{amount}', tx.formattedAmount)
                            .replaceAll('{status}', tx.statusLabel);
                    widget.onAskAi?.call(question);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(tx.statusIcon, size: 20, color: tx.statusColor),
                        const SizedBox(width: 12),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tx.customerEmail ??
                                    _t(
                                      'project_payment_anonymous',
                                      'Anonymous',
                                    ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tx.formattedAmount,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: tx.statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
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
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
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
  }
}
