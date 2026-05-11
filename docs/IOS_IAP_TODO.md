# iOS In-App Purchase Integration TODO

This document describes the remaining work required to complete Apple In-App Purchase for iOS.

## Current Client Status

The Flutter client now has:

- `in_app_purchase` integrated
- iOS purchase flow split from Stripe
- App Store product lookup in `lib/services/apple_iap_service.dart`
- iOS subscription entry in `lib/widgets/upgrade_plans_panel.dart`
- purchase confirmation placeholder calling:
  - `POST /api/package_order/apple-iap/confirm`

The current client can:

- query App Store products for iOS
- start an App Store purchase flow
- listen for completed purchases
- attempt to send completed purchase data to backend

The current client cannot fully credit users unless backend and App Store Connect are configured.

## App Store Connect Requirements

Create real IAP products for every iOS package that should be purchasable in app.

Required for each package:

- product id
- display name
- localization
- price tier
- review screenshot
- product type

Recommended mapping:

- monthly plan -> auto-renewable subscription
- yearly plan -> auto-renewable subscription
- one-time top-up / credit pack -> consumable

## Backend Requirements

The package list endpoint must return Apple product IDs:

- `ios_product_id`
- optionally `android_product_id`

Example package payload extension:

```json
{
  "id": 1,
  "name": "Pro Monthly",
  "price": 999,
  "interval": "month",
  "interval_count": 1,
  "ios_product_id": "ai.d1v.pro.monthly",
  "android_product_id": "ai.d1v.pro.monthly"
}
```

## Required Backend Endpoint

`POST /api/package_order/apple-iap/confirm`

### Request

```json
{
  "package_id": "1",
  "product_id": "ai.d1v.pro.monthly",
  "transaction_id": "1000001234567890",
  "verification_data": "<local verification data>",
  "server_verification_data": "<server verification data>",
  "status": "purchased"
}
```

### Expected backend responsibilities

- validate Apple transaction authenticity
- ensure transaction has not already been processed
- map `product_id` to internal package
- create order / purchase record
- grant entitlement or issue credits
- return normalized purchase result

### Suggested response

```json
{
  "ok": true,
  "credited": true,
  "package_id": "1",
  "product_id": "ai.d1v.pro.monthly",
  "transaction_id": "1000001234567890"
}
```

## Recommended Validation Rules

- reject unknown `product_id`
- reject duplicate `transaction_id`
- reject mismatched `package_id` and `product_id`
- persist raw Apple payload for audit/debugging
- store original transaction id for subscriptions if available later

## Remaining Client Improvements

- top-up dialog still uses Stripe on all non-iOS platforms
- iOS top-up flow is not yet migrated to App Store consumables
- purchase history still shows legacy Stripe-centric labels
- restore purchases UI is not yet exposed
- account/billing screens still need final copy cleanup after backend is ready

## Important Policy Note

Using Stripe to collect a card in the iOS app and then charging usage later is not a reliable workaround for Apple policy if the charge is for digital goods or digital services used in the app.

Apple evaluates:

- what the user is buying
- whether the purchase unlocks or funds in-app digital functionality

It does not materially help if payment is:

- collected up front
- tokenized for later billing
- charged by usage later

If the user is paying for app-usable digital services on iOS, Apple IAP is still the safe path.
