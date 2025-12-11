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

  /// 获取交易历史
  Future<List<PaymentTransaction>> getTransactions({
    int limit = 50,
    String? status,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = _apiClient.get<List<dynamic>>(
      '/api/wallet/transactions',
      queryParams: queryParams,
    );

    // 将 List<dynamic> 转换为 List<PaymentTransaction>
    final List<dynamic> data = await response;
    return data.map((item) => PaymentTransaction.fromJson(item)).toList();
  }
}
