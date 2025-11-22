import 'package:flutter/material.dart';
import '../widgets/balance_card.dart';
import '../widgets/order_history.dart';
import '../widgets/usage_stats.dart';
import '../widgets/credit_history.dart';
import '../screens/pricing_screen.dart';

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
      appBar: AppBar(
        title: const Text('Orders'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Balance'),
            Tab(text: 'Orders'),
            Tab(text: 'Usage'),
            Tab(text: 'Price'),
          ],
        ),
      ),
      body: TabBarView(
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
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(text: 'Purchases'),
              Tab(text: 'Credit History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              OrderHistory(),
              CreditHistory(),
            ],
          ),
        ),
      ],
    );
  }
}
