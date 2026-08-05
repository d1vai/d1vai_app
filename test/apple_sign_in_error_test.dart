import 'package:d1vai_app/utils/apple_sign_in_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('recognizes the standard Apple cancellation code', () {
    const error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'The operation was canceled.',
    );

    expect(isAppleSignInCancellation(error), isTrue);
  });

  test('recognizes Apple error 1000 reported as unknown', () {
    const error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.unknown,
      message:
          '未能完成操作。（com.apple.AuthenticationServices.AuthorizationError错误1000。）',
    );

    expect(isAppleSignInCancellation(error), isTrue);
  });

  test('does not hide other Apple authorization failures', () {
    const error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.failed,
      message: 'Authorization failed.',
    );

    expect(isAppleSignInCancellation(error), isFalse);
  });
}
