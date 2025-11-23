class PricingPlan {
  final String id;
  final String name;
  final String description;
  final List<String> features;
  final double? monthlyPrice;
  final double? yearlyPrice;
  final bool isFree;
  final bool isPopular;
  final bool isExclusive;
  final bool isOneTime;
  final String actionLabel;
  final String? stripePriceIdMonthly;
  final String? stripePriceIdYearly;
  final String? stripePriceIdOneTime;
  final double? oneTimePrice;
  final String? offerExpiresAt;

  PricingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.features,
    this.monthlyPrice,
    this.yearlyPrice,
    this.isFree = false,
    this.isPopular = false,
    this.isExclusive = false,
    this.isOneTime = false,
    required this.actionLabel,
    this.stripePriceIdMonthly,
    this.stripePriceIdYearly,
    this.stripePriceIdOneTime,
    this.oneTimePrice,
    this.offerExpiresAt,
  });

  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    return PricingPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      features: List<String>.from(json['features'] ?? []),
      monthlyPrice: json['monthly_price']?.toDouble(),
      yearlyPrice: json['yearly_price']?.toDouble(),
      isFree: json['is_free'] ?? false,
      isPopular: json['is_popular'] ?? false,
      isExclusive: json['is_exclusive'] ?? false,
      isOneTime: json['is_one_time'] ?? false,
      actionLabel: json['action_label'] ?? 'Get Started',
      stripePriceIdMonthly: json['stripe_price_id_monthly'],
      stripePriceIdYearly: json['stripe_price_id_yearly'],
      stripePriceIdOneTime: json['stripe_price_id_one_time'],
      oneTimePrice: json['one_time_price']?.toDouble(),
      offerExpiresAt: json['offer_expires_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'features': features,
      'monthly_price': monthlyPrice,
      'yearly_price': yearlyPrice,
      'is_free': isFree,
      'is_popular': isPopular,
      'is_exclusive': isExclusive,
      'is_one_time': isOneTime,
      'action_label': actionLabel,
      'stripe_price_id_monthly': stripePriceIdMonthly,
      'stripe_price_id_yearly': stripePriceIdYearly,
      'stripe_price_id_one_time': stripePriceIdOneTime,
      'one_time_price': oneTimePrice,
      'offer_expires_at': offerExpiresAt,
    };
  }
}

class PricingResponse {
  final List<PricingPlan> plans;
  final bool isYearly;

  PricingResponse({
    required this.plans,
    this.isYearly = false,
  });

  factory PricingResponse.fromJson(Map<String, dynamic> json) {
    final plansJson = json['plans'] as List<dynamic>? ?? [];
    return PricingResponse(
      plans: plansJson.map((p) => PricingPlan.fromJson(p)).toList(),
      isYearly: json['is_yearly'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plans': plans.map((p) => p.toJson()).toList(),
      'is_yearly': isYearly,
    };
  }
}
