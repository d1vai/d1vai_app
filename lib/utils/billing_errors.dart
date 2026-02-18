import '../core/api_client.dart';
import '../services/chat_service.dart';

const int insufficientBalanceErrorCode = 40201;

bool isInsufficientBalanceError(Object error) {
  if (error is ApiClientException) {
    if (error.code == insufficientBalanceErrorCode) return true;
    if (error.statusCode == 402) return true;
  }

  if (error is ChatException && error.cause != null) {
    if (isInsufficientBalanceError(error.cause!)) return true;
  }

  final text = error.toString().toLowerCase();
  return text.contains('insufficient balance') ||
      text.contains('balance is not enough') ||
      text.contains('余额不足') ||
      text.contains('40201');
}
