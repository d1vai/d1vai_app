import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../l10n/app_localizations.dart';
import '../models/organization.dart';
import '../providers/organization_provider.dart';
import '../services/organization_service.dart';
import '../services/wallet_service.dart';
import 'adaptive_modal.dart';
import 'snackbar_helper.dart';
import 'topup_dialog.dart';

class BalanceCard extends StatefulWidget {
  final WalletService? walletService;
  final OrganizationService? organizationService;

  const BalanceCard({super.key, this.walletService, this.organizationService});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with AutomaticKeepAliveClientMixin<BalanceCard> {
  late final WalletService _walletService;
  late final OrganizationService _organizationService;
  bool _isLoading = false;
  bool _isProcessingPayment = false;
  bool _showSuccessBanner = false;
  double _totalBalance = 0.0;
  double _expiringBalance = 0.0;
  double _nonExpiringBalance = 0.0;
  String? _expiringExpiresAt;
  int? _loadedOrganizationId;
  bool _hasLoadedScope = false;
  bool _scopeLoadScheduled = false;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _walletService = widget.walletService ?? WalletService();
    _organizationService = widget.organizationService ?? OrganizationService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeScope());
  }

  Future<void> _initializeScope() async {
    final organizations = context.read<OrganizationProvider>();
    await organizations.load();
    if (mounted) await _loadBalance();
  }

  Future<void> _handleTopUpSuccess() async {
    setState(() {
      _isProcessingPayment = true;
      _showSuccessBanner = false;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _loadBalance();
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
    });
  }

  Future<void> _loadBalance() async {
    final organizations = context.read<OrganizationProvider>();
    final organization = organizations.activeOrganization;
    final requestedOrganizationId = organization?.id;
    _loadedOrganizationId = requestedOrganizationId;
    _hasLoadedScope = true;
    setState(() {
      _isLoading = true;
    });

    try {
      if (organization == null) {
        final balance = await _walletService.getBalance();
        if (!mounted ||
            context.read<OrganizationProvider>().activeOrganizationId !=
                requestedOrganizationId) {
          return;
        }
        setState(() {
          _expiringBalance = balance.balanceExpiringUsd;
          _nonExpiringBalance = balance.balanceNonExpiringUsd;
          _expiringExpiresAt = balance.balanceExpiringExpiresAt;
          _totalBalance =
              balance.totalBalanceUsd ??
              (_expiringBalance + _nonExpiringBalance);
          _isLoading = false;
        });
        return;
      }
      final wallet = await _organizationService.getWallet(organization.slug);
      if (!mounted ||
          context.read<OrganizationProvider>().activeOrganizationId !=
              requestedOrganizationId) {
        return;
      }
      setState(() {
        _expiringBalance = wallet.expiringBalance;
        _nonExpiringBalance = wallet.nonexpiringBalance;
        _expiringExpiresAt = null;
        _totalBalance = wallet.totalBalance;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load balance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load balance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _transferToOrganization(
    List<OrganizationSummary> organizations,
  ) async {
    var selected = organizations.first;
    final amountController = TextEditingController();
    final transfer =
        await showDialog<({OrganizationSummary organization, double amount})>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(_t('organization_fund', 'Transfer balance')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selected.id,
                    decoration: InputDecoration(
                      labelText: _t('organization_manage', 'Organization'),
                      prefixIcon: const Icon(Icons.business_outlined),
                    ),
                    items: [
                      for (final organization in organizations)
                        DropdownMenuItem(
                          value: organization.id,
                          child: Text(
                            organization.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setDialogState(() {
                        selected = organizations.firstWhere(
                          (item) => item.id == id,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      prefixText: r'$ ',
                      labelText: _t('organization_amount', 'Amount'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'organization_fund_warning',
                      'This transfer cannot be reversed. Confirm the amount before continuing.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(dialogContext, (
                      organization: selected,
                      amount: amount,
                    ));
                  },
                  child: Text(_t('organization_confirm_transfer', 'Transfer')),
                ),
              ],
            ),
          ),
        );
    amountController.dispose();
    if (transfer == null || !mounted) return;
    try {
      await _organizationService.fundWallet(
        transfer.organization.slug,
        transfer.amount,
      );
      if (!mounted) return;
      await _loadBalance();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_fund_success', 'Balance transferred'),
        message: transfer.organization.name,
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_fund_failed', 'Transfer failed'),
          message: error.toString(),
        );
      }
    }
  }

  void _showBalanceDetails(BuildContext context) {
    showAdaptiveModal<void>(
      context: context,
      builder: (context) => AdaptiveModalContainer(
        maxWidth: 520,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Balance Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                'Non-expiring Balance',
                '\$${_nonExpiringBalance.toStringAsFixed(2)}',
                Icons.check_circle,
                Colors.green,
              ),
              const Divider(height: 32),
              _buildDetailRow(
                'Expiring Balance',
                '\$${_expiringBalance.toStringAsFixed(2)}',
                Icons.schedule,
                Colors.orange,
                subtitle: _expiringExpiresAt != null
                    ? 'Expires: ${_formatDate(_expiringExpiresAt!)}'
                    : 'No expiry date',
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated update time: ~15 minutes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build 来保持状态
    final organizations = context.watch<OrganizationProvider>();
    final activeOrganization = organizations.activeOrganization;
    final activeOrganizationId = activeOrganization?.id;
    if (organizations.context != null &&
        (!_hasLoadedScope || _loadedOrganizationId != activeOrganizationId) &&
        !_scopeLoadScheduled) {
      _scopeLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _scopeLoadScheduled = false;
        if (mounted) await _loadBalance();
      });
    }
    final manageableOrganizations =
        organizations.context?.organizations
            .where((organization) => organization.canManage)
            .toList() ??
        const <OrganizationSummary>[];
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: _showSuccessBanner && !isIOS
                  ? Container(
                      key: const ValueKey('success_banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Funds received successfully!',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_banner')),
            ),
            if (_showSuccessBanner && !isIOS) const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: _isProcessingPayment && !isIOS
                  ? Container(
                      key: const ValueKey('processing_banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Top-up initiated… balance updates after payment',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_processing')),
            ),
            if (_isProcessingPayment && !isIOS) const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeOrganization?.name ?? 'Account Balance',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        activeOrganization == null
                            ? 'Available credits for your projects'
                            : _t(
                                'organization_shared_balance',
                                'Shared balance',
                              ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadBalance,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh, size: 20),
                ),
                const SizedBox(width: 8),
                if (activeOrganization != null)
                  const SizedBox.shrink()
                else if (isIOS)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Billing managed outside iOS',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isLoading || _isProcessingPayment
                        ? null
                        : () => showAdaptiveModal(
                            context: context,
                            builder: (context) =>
                                TopUpDialog(onSuccess: _handleTopUpSuccess),
                          ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(_t('topup', 'Top up')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
            if (activeOrganization == null &&
                manageableOrganizations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _transferToOrganization(manageableOrganizations),
                  icon: const Icon(Icons.move_up_outlined),
                  label: Text(_t('organization_fund', 'Transfer balance')),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_isLoading && _totalBalance == 0.0)
              _buildSkeleton(context)
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Total Balance',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showBalanceDetails(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_totalBalance.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.deepPurple,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildBalanceRow(
                'Non-expiring',
                _nonExpiringBalance,
                Icons.check_circle,
                Colors.green.shade600,
              ),
              const SizedBox(height: 12),
              _buildBalanceRow(
                'Expiring',
                _expiringBalance,
                Icons.schedule,
                Colors.orange.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 100,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSkeletonRow(),
          const SizedBox(height: 12),
          _buildSkeletonRow(),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow() {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 80,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const Spacer(),
        Container(
          width: 60,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
