import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripePaymentService {
  StripePaymentService._();

  static const String publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String merchantIdentifier = String.fromEnvironment(
    'STRIPE_MERCHANT_IDENTIFIER',
    defaultValue: 'merchant.ai.d1v.d1vaiapp',
  );

  static const String merchantDisplayName = String.fromEnvironment(
    'STRIPE_MERCHANT_DISPLAY_NAME',
    defaultValue: 'd1v.ai',
  );

  static const String merchantCountryCode = String.fromEnvironment(
    'STRIPE_MERCHANT_COUNTRY_CODE',
    defaultValue: 'US',
  );

  static const String returnUrl = String.fromEnvironment(
    'STRIPE_RETURN_URL',
    defaultValue: 'd1vai://stripe-redirect',
  );

  static Future<void> initialize() async {
    if (kIsWeb || publishableKey.trim().isEmpty) {
      return;
    }
    Stripe.publishableKey = publishableKey;
    Stripe.merchantIdentifier = merchantIdentifier;
    Stripe.urlScheme = Uri.parse(returnUrl).scheme;
    await Stripe.instance.applySettings();
  }

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  static bool get isConfigured =>
      isSupportedPlatform && publishableKey.trim().isNotEmpty;

  static Future<void> presentPaymentSheet({
    required String clientSecret,
    required double amountUsd,
    String currencyCode = 'USD',
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Stripe is not configured. Missing STRIPE_PUBLISHABLE_KEY or unsupported platform.',
      );
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: merchantDisplayName,
        returnURL: returnUrl,
        style: ThemeMode.system,
        allowsDelayedPaymentMethods: false,
        applePay: PaymentSheetApplePay(
          merchantCountryCode: merchantCountryCode,
        ),
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: merchantCountryCode,
          currencyCode: currencyCode.toUpperCase(),
          amount: amountUsd.toStringAsFixed(2),
          testEnv: !publishableKey.startsWith('pk_live_'),
        ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }
}
