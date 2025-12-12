import '../core/api_client.dart';
import '../models/balance.dart';
import '../models/payment.dart';

class WalletService {
  final ApiClient _apiClient;

  WalletService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 获取账户余额
  Future<BalanceResponse> getBalance() async {
    return _apiClient.get<BalanceResponse>(
      '/api/wallet/balances',
      fromJsonT: (json) => BalanceResponse.fromJson(json),
    );
  }

  /// 获取信用卡记录
  Future<List<CreditIssuance>> getCreditIssuances({int limit = 50}) async {
    final response = _apiClient.get<List<dynamic>>(
      '/api/wallet/credit-issuances',
      queryParams: {'limit': limit.toString()},
    );

    // 将 List<dynamic> 转换为 List<CreditIssuance>
    final List<dynamic> data = await response;
    return data.map((item) => CreditIssuance.fromJson(item)).toList();
  }

  /// 初始化充值
  Future<Map<String, dynamic>> initiateTopup({
    required double amountUsd,
    required String successUrl,
    required String cancelUrl,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/wallet/topup/initiate',
      {
        'amount_usd': amountUsd,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      },
    );
  }

  /// 创建订阅链接（用于购买定价计划）
  Future<Map<String, dynamic>> createSubscribeLink({
    String? stripePriceId,
    String? packageId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final Map<String, dynamic> body = {
      'success_url': successUrl,
      'cancel_url': cancelUrl,
    };

    if (stripePriceId != null) {
      body['stripe_price_id'] = stripePriceId;
    } else if (packageId != null) {
      body['package_id'] = packageId;
    } else {
      throw Exception('Either stripe_price_id or package_id must be provided');
    }

    return _apiClient.post<Map<String, dynamic>>(
      '/api/wallet/subscribe',
      body,
    );
  }

  /// 获取交易历史（对齐 Web 端订单记录）
  Future<List<PaymentTransaction>> getTransactions({
    int limit = 50,
  }) async {
    // 对齐 d1vai Web：使用 `/api/package_order/my-orders` 作为用户购买记录接口
    // 包含套餐订单 + 充值（topup）两类记录
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'include_topups': 'true',
    };

    final List<dynamic> data = await _apiClient.get<List<dynamic>>(
      '/api/package_order/my-orders',
      queryParams: queryParams,
    );

    // 将套餐订单 / 充值记录映射为统一的 PaymentTransaction 结构，方便 UI 复用
    return data.map((item) {
      final map = (item as Map).cast<String, dynamic>();

      final orderType = (map['order_type'] ?? 'package').toString();
      final packageName = (map['package_name'] ?? '') as String;

      // 后端返回的价格是整型分（cents）
      final priceRaw = map['package_price'];
      final priceNum = priceRaw is num ? priceRaw.toDouble() : 0.0;
      final amount = priceNum / 100.0;

      final currencyRaw = map['package_currency'];
      final currency = (currencyRaw is String && currencyRaw.isNotEmpty)
          ? currencyRaw.toUpperCase()
          : 'USD';

      final statusRaw = map['plan_status'];
      final status =
          statusRaw is String && statusRaw.isNotEmpty ? statusRaw : 'paid';

      final createdAt = map['created_at']?.toString();
      final updatedAt = map['updated_at']?.toString();

      // 构造一个符合 PaymentTransaction.fromJson 预期的中间结构
      final txJson = <String, dynamic>{
        'id': map['id']?.toString() ?? '',
        'product_id': map['package_info_id']?.toString(),
        'product_name': orderType == 'topup'
            ? 'Top-up'
            : (packageName.isEmpty ? null : packageName),
        'amount': amount,
        'currency': currency,
        'status': status,
        'customer_email': null,
        'created_at': createdAt ?? updatedAt,
        'completed_at': updatedAt,
        // 后端目前未暴露支付方式，这里统一标记为 stripe，主要用于 UI 展示
        'payment_method': 'stripe',
      };

      return PaymentTransaction.fromJson(txJson);
    }).toList();
  }
}
