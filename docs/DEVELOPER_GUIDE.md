# Developer Guide

`d1vai_app` is the Flutter mobile client for `d1v.ai`, focused on mobile usage scenarios such as authentication, project management, AI chat, deployment visibility, analytics, docs/community access, orders, and account settings.

`d1vai_app` 是 `d1v.ai` 的 Flutter 移动客户端，面向移动端使用场景，提供登录、项目管理、AI 聊天、部署与实时分析、文档与社区、订单与账户设置等能力。

## Feature Overview

- Authentication and account
  Email verification login, password login, Solana login, Sui login, onboarding, invitation flows, profile maintenance.
- Main navigation areas
  Dashboard, Community, Docs, Orders, Settings.
- Project workflows
  Project list and search, project detail tabs, project chat, code/file viewer, analytics and deployment context.
- Internationalization and themes
  Built-in multilingual support and dark/light theme switching.

## Tech Stack

- Flutter / Dart (`sdk: ^3.10.0`)
- State management: `provider`
- Routing: `go_router`
- Networking: `http`
- Local storage: `shared_preferences`
- Charts: `fl_chart`

## Project Structure

```text
lib/
  core/        # API client, theme, global event bus
  models/      # Data models
  providers/   # App state (auth, theme, locale, project, etc.)
  services/    # Business services (user, project, analytics, wallet, workspace, etc.)
  screens/     # Screens
  widgets/     # Components
  l10n/        # Localization resources and generated code
tool/
  gen_l10n.dart  # Runtime localization mapping generator
test/
```

## Environment Requirements

- Flutter SDK compatible with the project Dart version
- Xcode for iOS
- Android Studio / Android SDK for Android

## Quick Start

1. Install dependencies

```bash
flutter pub get
```

2. Run the app

```bash
flutter run
```

3. Optional: override API base URL at build time

```bash
flutter run --dart-define=API_BASE_URL=https://api.d1v.ai
```

4. Optional: provide local Stripe debug values from a gitignored file

```bash
flutter run --dart-define-from-file=.env/dev.json
```

## API Configuration

- Default API base URL: `https://api.d1v.ai`
- Runtime override is available inside the app: `Settings → Profile → API`
- `Copy diagnostics` exports key troubleshooting information, including:
  - effective base URL
  - whether auth token exists and its suffix
  - JWT claims such as `sub/type/exp` when available
  - latest workspace status and latest API error

## Troubleshooting: project creation returns 500

If project creation fails in `d1vai_app` while the web app works:

1. Go to `Settings → Profile → API` and tap `Copy diagnostics`
2. Confirm `effective_base_url` is `https://api.d1v.ai`
3. Confirm `auth_token_present=true`
4. Compare App and Web/curl `jwt_sub` / `jwt_type` or token suffix

## Local Stripe Debug Setup

For local `flutter run` / debug builds, keep Stripe compile-time values in a local file:

1. Copy `.env/dev.example.json` to `.env/dev.json`
2. Replace `STRIPE_PUBLISHABLE_KEY` with your real key
3. Run with:

```bash
flutter run --dart-define-from-file=.env/dev.json
```

The `.env/` folder is gitignored by default, so local keys stay out of the repo.

## Localization Workflow

- Source of truth: `lib/l10n/arb/app_*.arb`
- After changing ARB files, generate runtime mappings:

```bash
dart run tool/gen_l10n.dart
```

- Consistency check:
  `test/l10n_arb_consistency_test.dart` verifies that locale keys stay aligned with `app_en.arb`

## Testing

```bash
flutter test
```

## Android Release Signing

- The repository supports loading release signing config from `android/key.properties`
- You can copy `android/key.properties.example` to `android/key.properties` and fill in real keystore values
- If `android/key.properties` is not provided, the app falls back to debug signing for local sideloading and GitHub APK distribution
- Before publishing to any app store, switch to a proper release signing setup
