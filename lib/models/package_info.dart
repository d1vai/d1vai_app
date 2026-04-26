class PackageInfo {
  final int id;
  final String name;
  final String description;
  final int quota;
  final int duration;
  final int price;
  final String? interval;
  final int? intervalCount;
  final String stripeCurrency;
  final int creditCents;

  const PackageInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.quota,
    required this.duration,
    required this.price,
    required this.interval,
    required this.intervalCount,
    required this.stripeCurrency,
    required this.creditCents,
  });

  factory PackageInfo.fromJson(Map<String, dynamic> json) {
    return PackageInfo(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      quota: json['quota'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      price: json['price'] as int? ?? 0,
      interval: json['interval']?.toString(),
      intervalCount: json['interval_count'] as int?,
      stripeCurrency: (json['stripe_currency'] ?? 'usd').toString(),
      creditCents: json['credit_cents'] as int? ?? 0,
    );
  }

  bool get isSubscription => interval != null && interval!.isNotEmpty;

  bool get isMonthly => interval == 'month' && (intervalCount ?? 1) == 1;

  bool get isYearly => interval == 'year' && (intervalCount ?? 1) == 1;

  double get priceUsd => price / 100.0;

  String get billingLabel {
    if (isYearly) return '/year';
    if (isMonthly) return '/month';
    if (!isSubscription) return 'one-time';
    final count = intervalCount ?? 1;
    return '/$count ${interval ?? 'period'}';
  }
}
