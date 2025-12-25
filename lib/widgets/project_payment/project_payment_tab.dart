import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../select.dart';
import '../snackbar_helper.dart';

/// 项目详情页 - Payment Tab
class ProjectPaymentTab extends StatefulWidget {
  final String projectId;
  final void Function(String prompt)? onAskAi;

  const ProjectPaymentTab({
    super.key,
    required this.projectId,
    this.onAskAi,
  });

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
      final products =
          productsData.map((item) => PayProduct.fromJson(item)).toList();
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
      SnackBarHelper.showError(
        context,
        title: 'Load failed',
        message: msg,
        actionLabel: authExpired ? 'Re-login' : null,
        onActionPressed: authExpired
            ? () {
                unawaited(_logoutAndGoLogin());
              }
            : null,
      );
    }
  }

  Future<void> _logoutAndGoLogin() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    context.go('/login');
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
                    label: const Text('Retry'),
                  ),
                  if (authExpired)
                    OutlinedButton.icon(
                      onPressed: () {
                        unawaited(_logoutAndGoLogin());
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Re-login'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_payMetrics != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _PayMetricCard(
                      title: 'Total Revenue',
                      value: _payMetrics!.formattedRevenue,
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMetricCard(
                      title: 'Transactions',
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
                      title: 'Conversion Rate',
                      value: _payMetrics!.formattedConversionRate,
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMetricCard(
                      title: 'Active Customers',
                      value: _payMetrics!.activeCustomers.toString(),
                      icon: Icons.people,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'Payment not activated yet',
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddPayProductDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  'No payment products yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ..._payProducts.map((product) {
                return InkWell(
                  onTap: () {
                    final question =
                        'Can you analyze the payment product "${product.name}" and provide suggestions on pricing strategy, configuration, or marketing improvements?';
                    widget.onAskAi?.call(question);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (product.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  product.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: product.price > 0
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'link',
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 18),
                                  SizedBox(width: 8),
                                  Text('Get Link'),
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
                                title: 'Payment Link',
                                message: 'Getting payment link...',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  'No transactions yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ..._paymentTransactions.take(5).map((tx) {
                return InkWell(
                  onTap: () {
                    final question =
                        'Can you analyze this payment transaction (${tx.formattedAmount}, ${tx.statusLabel}) and provide insights about payment patterns or recommendations?';
                    widget.onAskAi?.call(question);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tx.statusIcon,
                          size: 20,
                          color: tx.statusColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.productName ?? 'Unknown Product',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tx.customerEmail ?? 'Anonymous',
                                style: TextStyle(
                                  fontSize: 12,
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
                              tx.formattedAmount,
                              style: const TextStyle(
                                fontSize: 14,
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment Product'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g., Premium Plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your product',
                    border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
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
                  title: const Text('Active'),
                  subtitle: const Text('Product is available for purchase'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();
                      final priceText = priceController.text.trim();

                      if (name.isEmpty) {
                        setDialogState(() {
                          error = 'Product name is required';
                        });
                        return;
                      }

                      if (priceText.isEmpty) {
                        setDialogState(() {
                          error = 'Price is required';
                        });
                        return;
                      }

                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        setDialogState(() {
                          error = 'Please enter a valid price';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        error = '';
                      });

                      try {
                        await Future.delayed(const Duration(seconds: 1));

                        if (!mounted) return;

                        final product = PayProduct(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          description:
                              description.isEmpty ? null : description,
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
                          error = 'Failed to add product: $e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPayProductDialog(BuildContext context, PayProduct product) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController =
        TextEditingController(text: product.description ?? '');
    final priceController =
        TextEditingController(text: product.price.toString());
    String selectedCurrency = product.currency;
    bool isActive = product.isActive;
    String error = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Payment Product'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g., Premium Plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your product',
                    border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
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
                  title: const Text('Active'),
                  subtitle: const Text('Product is available for purchase'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();
                      final priceText = priceController.text.trim();

                      if (name.isEmpty) {
                        setDialogState(() {
                          error = 'Product name is required';
                        });
                        return;
                      }

                      if (priceText.isEmpty) {
                        setDialogState(() {
                          error = 'Price is required';
                        });
                        return;
                      }

                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        setDialogState(() {
                          error = 'Please enter a valid price';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        error = '';
                      });

                      try {
                        await Future.delayed(const Duration(seconds: 1));

                        if (!mounted) return;

                        setState(() {
                          final index = _payProducts.indexOf(product);
                          if (index != -1) {
                            _payProducts[index] = PayProduct(
                              id: product.id,
                              name: name,
                              description:
                                  description.isEmpty ? null : description,
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
                          error = 'Failed to update product: $e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
