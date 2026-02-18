import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/balance_card.dart';
import '../widgets/order_history.dart';
import '../widgets/usage_stats.dart';
import '../widgets/credit_history.dart';
import '../widgets/wallet_usage_history.dart';
import '../screens/pricing_screen.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../widgets/d1v_app_bar.dart';
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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
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
        return 3;
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
        appBar: AppBar(title: const Text('Orders')),
        body: LoginRequiredView(
          message:
              loc?.translate('login_required_orders_message') ??
              'Please login first.',
          onAction: () => context.go('/login'),
        ),
      );
    }

    return Scaffold(
      appBar: D1VAppBar(
        title: Text(loc?.translate('orders_title') ?? 'Orders'),
        controller: _tabController,
        tabs: [
          D1VTab(text: loc?.translate('orders_tab_balance') ?? 'Balance'),
          D1VTab(text: loc?.translate('orders_tab_orders') ?? 'Orders'),
          D1VTab(text: loc?.translate('orders_tab_usage') ?? 'Usage'),
          D1VTab(text: loc?.translate('orders_tab_price') ?? 'Price'),
        ],
      ),
      body: D1VTabBarView(
        controller: _tabController,
        children: const [
          BalanceCard(),
          OrdersTabContent(),
          UsageStats(),
          PricingScreen(),
        ],
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
