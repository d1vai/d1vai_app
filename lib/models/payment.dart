import 'package:flutter/material.dart';

class PayProduct {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final bool isActive;
  final String? createdAt;

  PayProduct({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.isActive = true,
    this.createdAt,
  });

  factory PayProduct.fromJson(Map<String, dynamic> json) {
    return PayProduct(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      currency: json['currency'] ?? 'USD',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }

  String get formattedPrice {
    if (price == 0.0) {
      return 'Free';
    }
    return '\$${price.toStringAsFixed(2)} $currency';
  }
}

class PaymentTransaction {
  final String id;
  final String? productId;
  final String? productName;
  final double amount;
  final String currency;
  final String status;
  final String? customerEmail;
  final String? createdAt;
  final String? completedAt;
  final String? paymentMethod;

  PaymentTransaction({
    required this.id,
    this.productId,
    this.productName,
    required this.amount,
    required this.currency,
    required this.status,
    this.customerEmail,
    this.createdAt,
    this.completedAt,
    this.paymentMethod,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] ?? '',
      productId: json['product_id'],
      productName: json['product_name'],
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'pending',
      customerEmail: json['customer_email'],
      createdAt: json['created_at'],
      completedAt: json['completed_at'],
      paymentMethod: json['payment_method'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'customer_email': customerEmail,
      'created_at': createdAt,
      'completed_at': completedAt,
      'payment_method': paymentMethod,
    };
  }

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'success':
      case 'succeeded':
      case 'paid':
        return 'Completed';
      case 'pending':
      case 'processing':
        return 'Pending';
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return 'Failed';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'success':
      case 'succeeded':
      case 'paid':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'success':
      case 'succeeded':
      case 'paid':
        return Icons.check_circle;
      case 'pending':
      case 'processing':
        return Icons.hourglass_empty;
      case 'failed':
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.undo;
      default:
        return Icons.info;
    }
  }
}

class PayMetrics {
  final double totalRevenue;
  final int totalTransactions;
  final double conversionRate;
  final int activeCustomers;
  final String? period;

  PayMetrics({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.conversionRate,
    required this.activeCustomers,
    this.period,
  });

  factory PayMetrics.fromJson(Map<String, dynamic> json) {
    return PayMetrics(
      totalRevenue: json['total_revenue'] != null
          ? (json['total_revenue'] as num).toDouble()
          : 0.0,
      totalTransactions: json['total_transactions'] != null
          ? (json['total_transactions'] as num).toInt()
          : 0,
      conversionRate: json['conversion_rate'] != null
          ? (json['conversion_rate'] as num).toDouble()
          : 0.0,
      activeCustomers: json['active_customers'] != null
          ? (json['active_customers'] as num).toInt()
          : 0,
      period: json['period'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'total_transactions': totalTransactions,
      'conversion_rate': conversionRate,
      'active_customers': activeCustomers,
      'period': period,
    };
  }

  String get formattedRevenue {
    return '\$${totalRevenue.toStringAsFixed(2)}';
  }

  String get formattedConversionRate {
    return '${conversionRate.toStringAsFixed(1)}%';
  }
}
