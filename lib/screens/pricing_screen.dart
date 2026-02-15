import 'package:flutter/material.dart';
import 'dart:async';
import 'package:d1vai_app/models/pricing_plan.dart';
import 'package:d1vai_app/services/wallet_service.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

/// Countdown Timer Widget for limited offers
class CountdownTimer extends StatefulWidget {
  final DateTime targetDate;
  final String? title;

  const CountdownTimer({super.key, required this.targetDate, this.title});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final difference = widget.targetDate.difference(now);
    setState(() {
      _timeLeft = difference.isNegative ? Duration.zero : difference;
    });
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeUnit(_pad(days), 'Days'),
            _buildTimeUnit(_pad(hours), 'Hrs'),
            _buildTimeUnit(_pad(minutes), 'Min'),
            _buildTimeUnit(_pad(seconds), 'Sec'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange.shade600,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingScreenState extends State<PricingScreen> {
  final WalletService _walletService = WalletService();
  bool _isYearly = false;
  bool _isLoading = false;

  // 模拟定价计划数据（实际应用中应该从 API 获取）
  final List<PricingPlan> _plans = [
    PricingPlan(
      id: 'free',
      name: 'Free',
      description: 'Get started with basic features',
      features: [
        '\$1.5 / month',
        '3 projects',
        'Basic AI chat',
        'Community support',
      ],
      isFree: true,
      actionLabel: 'Get Started',
    ),
    PricingPlan(
      id: 'experience',
      name: 'Experience',
      description: 'For individuals and light usage',
      features: [
        '\$10 / month',
        'Standard limits',
        'AI chat',
        'Community support',
      ],
      monthlyPrice: 9.5,
      yearlyPrice: 99,
      actionLabel: 'Choose Experience',
    ),
    PricingPlan(
      id: 'pro',
      name: 'Pro',
      description: 'For professionals and heavy usage',
      features: [
        '\$20 / month',
        'Higher limits',
        'Advanced features',
        'Priority support',
        'More customization',
      ],
      monthlyPrice: 18,
      yearlyPrice: 189,
      isPopular: true,
      actionLabel: 'Choose Pro',
    ),
    PricingPlan(
      id: 'lifetime',
      name: 'Lifetime Plan',
      description: 'One-time payment for lifetime access',
      features: [
        '\$30/mo × every-mo',
        'Early feature access',
        'Developer chat',
        'Founders badge',
      ],
      isOneTime: true,
      oneTimePrice: 350,
      isExclusive: true,
      offerExpiresAt: '2025-11-25T00:00:00',
      actionLabel: 'Join Now',
    ),
  ];

  Future<void> _handlePlanPurchase(PricingPlan plan) async {
    if (plan.isFree) {
      // 免费计划，跳转到登录或注册
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free plan - login to activate'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 创建成功和取消 URL
      final Uri currentUri = Uri.base;
      final successUrl =
          '${currentUri.scheme}://${currentUri.host}/orders?pay=success';
      final cancelUrl = currentUri.toString();

      String? stripePriceId;
      if (plan.isOneTime) {
        stripePriceId = plan.stripePriceIdOneTime;
      } else if (_isYearly && plan.stripePriceIdYearly != null) {
        stripePriceId = plan.stripePriceIdYearly;
      } else if (!plan.isOneTime && plan.stripePriceIdMonthly != null) {
        stripePriceId = plan.stripePriceIdMonthly;
      }

      if (stripePriceId == null) {
        // 模拟购买流程（实际应用中需要配置 Stripe price IDs）
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase flow not configured - Demo mode'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 调用 API 创建订阅链接
      final response = await _walletService.createSubscribeLink(
        stripePriceId: stripePriceId,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      final checkoutUrl = response['url'] as String?;
      if (mounted && checkoutUrl != null) {
        // 跳转到 Stripe 购买页面
        // 实际应用中需要使用 WebView 或 url_launcher
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecting to Stripe checkout...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Purchase failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 月付/年付切换
          Center(
            child: ToggleButtons(
              isSelected: [_isYearly, !_isYearly],
              onPressed: (index) {
                setState(() {
                  _isYearly = index == 0;
                });
              },
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              selectedColor: Colors.white,
              fillColor: Colors.deepPurple,
              color: Colors.deepPurple,
              constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Yearly'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 定价计划列表
          ..._plans.map((plan) => _buildPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PricingPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: plan.isPopular || plan.isExclusive ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: plan.isPopular
                ? Colors.deepPurple
                : plan.isExclusive
                ? Colors.orange
                : Colors.grey.shade300,
            width: plan.isPopular || plan.isExclusive ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 计划名称和描述
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (plan.isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Popular',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (plan.isExclusive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Limited',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 价格显示
              _buildPriceDisplay(plan),
              const SizedBox(height: 8),

              // 倒计时显示（仅对限时优惠）
              if (plan.isExclusive && plan.offerExpiresAt != null)
                _buildCountdown(plan.offerExpiresAt!),

              const SizedBox(height: 16),

              // 功能列表
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 购买按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _handlePlanPurchase(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.isPopular
                        ? Colors.deepPurple
                        : plan.isExclusive
                        ? Colors.orange
                        : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          plan.actionLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDisplay(PricingPlan plan) {
    if (plan.isFree) {
      return const Text(
        'Free',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      );
    }

    if (plan.isOneTime) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '\$${plan.oneTimePrice?.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            'one-time',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final price = _isYearly && plan.yearlyPrice != null
        ? plan.yearlyPrice
        : plan.monthlyPrice;

    if (price == null) {
      return const Text('Custom');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          _isYearly ? '/year' : '/month',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        if (_isYearly && plan.monthlyPrice != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Save \$${((plan.monthlyPrice! * 12) - plan.yearlyPrice!).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCountdown(String offerExpiresAt) {
    try {
      final targetDate = DateTime.parse(offerExpiresAt);
      final now = DateTime.now();

      if (targetDate.isBefore(now)) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Offer expired',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: CountdownTimer(targetDate: targetDate, title: 'Offer ends in'),
      );
    } catch (e) {
      // 如果日期解析失败，不显示倒计时
      return const SizedBox.shrink();
    }
  }
}
