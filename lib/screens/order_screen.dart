import 'package:flutter/material.dart';
import '../widgets/balance_card.dart';
import '../widgets/order_history.dart';
import '../widgets/usage_stats.dart';
import '../widgets/credit_history.dart';
import '../screens/pricing_screen.dart';
import '../widgets/d1v_tab_bar_view.dart';
import '../widgets/d1v_app_bar.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: D1VAppBar(
        title: const Text('Orders'),
        controller: _tabController,
        tabs: const [
          D1VTab(text: 'Balance'),
          D1VTab(text: 'Orders'),
          D1VTab(text: 'Usage'),
          D1VTab(text: 'Price'),
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: D1VTabBar(
            controller: _tabController,
            tabs: const [
              D1VTab(text: 'Purchases'),
              D1VTab(text: 'Credit History'),
            ],
          ),
        ),
        Expanded(
          child: D1VTabBarView(
            controller: _tabController,
            children: const [OrderHistory(), CreditHistory()],
          ),
        ),
      ],
    );
  }
}
