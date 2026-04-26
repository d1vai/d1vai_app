import 'package:flutter/material.dart';

import '../models/package_info.dart';
import '../services/stripe_payment_service.dart';
import '../services/wallet_service.dart';

class UpgradePlansPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final bool showAsDrawer;

  const UpgradePlansPanel({super.key, this.onClose, this.showAsDrawer = false});

  @override
  State<UpgradePlansPanel> createState() => _UpgradePlansPanelState();
}

class _UpgradePlansPanelState extends State<UpgradePlansPanel> {
  final WalletService _walletService = WalletService();

  bool _isYearly = false;
  bool _isLoading = true;
  String? _error;
  String? _activePackageId;
  List<PackageInfo> _packages = const [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final packages = await _walletService.getPackages();
      final subscriptions =
          packages.where((item) => item.isSubscription).toList()
            ..sort((a, b) => a.price.compareTo(b.price));
      if (!mounted) return;
      setState(() {
        _packages = subscriptions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<PackageInfo> get _visiblePackages {
    final filtered = _packages.where((item) {
      if (_isYearly) return item.isYearly;
      return item.isMonthly;
    }).toList();
    if (filtered.isNotEmpty) return filtered;
    return _packages;
  }

  PackageInfo? get _featuredPackage {
    final visible = _visiblePackages;
    if (visible.isEmpty) return null;
    return visible[visible.length ~/ 2];
  }

  Future<void> _handleSubscribe(PackageInfo package) async {
    if (!StripePaymentService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stripe mobile payment is not configured in this build.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _activePackageId = package.id.toString();
    });

    try {
      final response = await _walletService.subscribePlanApp(
        packageId: package.id.toString(),
      );
      final clientSecret = response['client_secret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Missing client secret');
      }

      await StripePaymentService.presentPaymentSheet(
        clientSecret: clientSecret,
        amountUsd: package.priceUsd,
        currencyCode: package.stripeCurrency.toUpperCase(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription payment submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activePackageId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visiblePackages = _visiblePackages;
    final featured = _featuredPackage;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      colorScheme.primary.withValues(alpha: 0.16),
                      colorScheme.surface,
                    ),
                    Color.alphaBlend(
                      const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                      colorScheme.surface,
                    ),
                  ],
                ),
              ),
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
                              'Upgrade',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.9,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose a plan built for sustained usage, faster limits, and cleaner billing.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _SignalPill(icon: Icons.apple, label: 'Apple Pay'),
                      const SizedBox(width: 8),
                      _SignalPill(icon: Icons.android, label: 'Google Pay'),
                      const SizedBox(width: 8),
                      _SignalPill(icon: Icons.lock_outline, label: 'Stripe'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<bool>(value: false, label: Text('Monthly')),
                      ButtonSegment<bool>(value: true, label: Text('Yearly')),
                    ],
                    selected: {_isYearly},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isYearly = selection.first;
                      });
                    },
                  ),
                  if (featured != null) ...[
                    const SizedBox(height: 18),
                    _PlanLead(plan: featured, isYearly: _isYearly),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPackages,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _PanelState(
                        title: 'Failed to load plans',
                        detail: _error!,
                        actionLabel: 'Retry',
                        onAction: _loadPackages,
                      )
                    else if (visiblePackages.isEmpty)
                      const _PanelState(
                        title: 'No plans available',
                        detail:
                            'Subscription packages will appear here when published.',
                      )
                    else
                      ...List.generate(visiblePackages.length, (index) {
                        final package = visiblePackages[index];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 220 + (index * 60)),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset((1 - value) * 14, 0),
                                child: child,
                              ),
                            );
                          },
                          child: _UpgradePlanTile(
                            plan: package,
                            featuredPlanId: featured?.id,
                            busy: _activePackageId == package.id.toString(),
                            onTap: () => _handleSubscribe(package),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Text(
                      StripePaymentService.isConfigured
                          ? 'Payments are processed natively in-app. Balance top-up stays in USD for now.'
                          : 'This build still needs STRIPE_PUBLISHABLE_KEY before native checkout can open.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanLead extends StatelessWidget {
  final PackageInfo plan;
  final bool isYearly;

  const _PlanLead({required this.plan, required this.isYearly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.auto_awesome, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
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
                '\$${plan.priceUsd.toStringAsFixed(plan.price % 100 == 0 ? 0 : 2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                plan.billingLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpgradePlanTile extends StatelessWidget {
  final PackageInfo plan;
  final int? featuredPlanId;
  final bool busy;
  final VoidCallback onTap;

  const _UpgradePlanTile({
    required this.plan,
    required this.featuredPlanId,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFeatured = plan.id == featuredPlanId;
    final creditsUsd = plan.creditCents / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFeatured
              ? colorScheme.primary.withValues(alpha: 0.28)
              : colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              (isFeatured ? colorScheme.primary : colorScheme.surfaceTint)
                  .withValues(alpha: isFeatured ? 0.12 : 0.04),
              colorScheme.surface,
            ),
            colorScheme.surface,
          ],
        ),
      ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isFeatured) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Best fit',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${plan.priceUsd.toStringAsFixed(plan.price % 100 == 0 ? 0 : 2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    plan.billingLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.bolt,
                label: '\$${creditsUsd.toStringAsFixed(0)} credits',
              ),
              _MetaChip(
                icon: Icons.schedule,
                label:
                    '${plan.intervalCount ?? 1} ${plan.interval ?? 'period'} cycle',
              ),
              _MetaChip(icon: Icons.tune, label: 'Quota ${plan.quota}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  isFeatured
                      ? 'Balanced for most active builders'
                      : 'Designed for focused production usage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: busy ? null : onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: isFeatured
                      ? colorScheme.primary
                      : Color.alphaBlend(
                          colorScheme.primary.withValues(alpha: 0.9),
                          colorScheme.surface,
                        ),
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upgrade'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SignalPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _PanelState extends StatelessWidget {
  final String title;
  final String detail;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _PanelState({
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => onAction!.call(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
