class BalanceResponse {
  final double balanceExpiringUsd;
  final String? balanceExpiringExpiresAt;
  final double balanceNonExpiringUsd;
  final double? totalBalanceUsd;

  BalanceResponse({
    required this.balanceExpiringUsd,
    this.balanceExpiringExpiresAt,
    required this.balanceNonExpiringUsd,
    this.totalBalanceUsd,
  });

  factory BalanceResponse.fromJson(Map<String, dynamic> json) {
    return BalanceResponse(
      balanceExpiringUsd: (json['balance_expiring_usd'] ?? 0.0).toDouble(),
      balanceExpiringExpiresAt: json['balance_expiring_expires_at'],
      balanceNonExpiringUsd: (json['balance_nonexpiring_usd'] ?? 0.0)
          .toDouble(),
      totalBalanceUsd: json['total_balance_usd']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance_expiring_usd': balanceExpiringUsd,
      'balance_expiring_expires_at': balanceExpiringExpiresAt,
      'balance_nonexpiring_usd': balanceNonExpiringUsd,
      'total_balance_usd': totalBalanceUsd,
    };
  }
}

class CreditIssuance {
  final String id;
  final double amountUsd;
  final String direction;
  final String issuedAt;
  final String? bucket;
  final String? expiresAt;
  final String? source;

  CreditIssuance({
    required this.id,
    required this.amountUsd,
    required this.direction,
    required this.issuedAt,
    this.bucket,
    this.expiresAt,
    this.source,
  });

  factory CreditIssuance.fromJson(Map<String, dynamic> json) {
    return CreditIssuance(
      id: json['id'].toString(),
      amountUsd: (json['amount_usd'] ?? 0.0).toDouble(),
      direction: (json['direction'] ?? 'credit').toString(),
      issuedAt: json['issued_at'] ?? '',
      bucket: json['bucket'],
      expiresAt: json['expires_at'],
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount_usd': amountUsd,
      'direction': direction,
      'issued_at': issuedAt,
      'bucket': bucket,
      'expires_at': expiresAt,
      'source': source,
    };
  }
}
