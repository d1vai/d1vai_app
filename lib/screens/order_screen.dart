import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/balance_card.dart';
import '../widgets/order_history.dart';
import '../widgets/usage_stats.dart';
import '../widgets/credit_history.dart';
import '../widgets/wallet_usage_history.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../widgets/d1v_app_bar.dart';
import '../widgets/upgrade_plans_panel.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/login_required_view.dart';

class OrderScreen extends StatefulWidget {
  final String? initialTab;

  const OrderScreen({super.key, this.initialTab});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _initialIndexFromTab(widget.initialTab),
    );
  }

  int _initialIndexFromTab(String? tab) {
    switch ((tab ?? '').trim().toLowerCase()) {
      case 'balance':
        return 0;
      case 'orders':
      case 'orderhistory':
        return 1;
      case 'usage':
      case 'dbusage':
      case 'llmusage':
      case 'builderusage':
        return 2;
      case 'price':
      case 'pricing':
        return 0;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final loc = AppLocalizations.of(context);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc?.translate('orders_title') ?? 'Orders')),
        body: LoginRequiredView(
          message:
              loc?.translate('login_required_orders_message') ??
              'Please login first.',
          onAction: () => context.go('/login'),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width < 680
            ? MediaQuery.of(context).size.width
            : 460,
        child: Drawer(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: UpgradePlansPanel(
            showAsDrawer: true,
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      appBar: D1VAppBar(
        title: Text(loc?.translate('orders_title') ?? 'Orders'),
        controller: _tabController,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _UpgradeButton(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
        tabs: [
          D1VTab(text: loc?.translate('orders_tab_balance') ?? 'Balance'),
          D1VTab(text: loc?.translate('orders_tab_orders') ?? 'Orders'),
          D1VTab(text: loc?.translate('orders_tab_usage') ?? 'Usage'),
        ],
      ),
      body: D1VTabBarView(
        controller: _tabController,
        children: const [BalanceCard(), OrdersTabContent(), UsageStats()],
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _UpgradeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: colorScheme.onPrimary.withValues(alpha: 0.18),
          ),
        ),
      ),
      icon: const Icon(Icons.north_east, size: 16),
      label: Text(
        loc?.translate('upgrade_title') ?? 'Upgrade',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class OrdersTabContent extends StatefulWidget {
  const OrdersTabContent({super.key});

  @override
  State<OrdersTabContent> createState() => _OrdersTabContentState();
}

class _OrdersTabContentState extends State<OrdersTabContent>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: D1VTabBar(
            controller: _tabController,
            tabs: [
              D1VTab(
                text: loc?.translate('orders_subtab_purchases') ?? 'Purchases',
              ),
              D1VTab(
                text:
                    loc?.translate('orders_subtab_credit_history') ??
                    'Credit History',
              ),
              D1VTab(text: loc?.translate('orders_subtab_usage') ?? 'Usage'),
            ],
          ),
        ),
        Expanded(
          child: D1VTabBarView(
            controller: _tabController,
            children: const [
              OrderHistory(),
              CreditHistory(),
              WalletUsageHistory(),
            ],
          ),
        ),
      ],
    );
  }
}
