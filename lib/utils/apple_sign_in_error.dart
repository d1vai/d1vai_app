import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool isAppleSignInCancellation(Object error) {
  if (error is! SignInWithAppleAuthorizationException) return false;
  if (error.code == AuthorizationErrorCode.canceled) return true;

  final message = error.message.toLowerCase();
  return error.code == AuthorizationErrorCode.unknown &&
      (message.contains('authorizationerror') && message.contains('1000'));
}
