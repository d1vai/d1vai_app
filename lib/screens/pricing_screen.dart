import 'package:flutter/material.dart';
import '../widgets/upgrade_plans_panel.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const UpgradePlansPanel(),
    );
  }
}
