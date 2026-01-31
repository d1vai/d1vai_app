# d1vai_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## API Settings

- Default API base URL is `https://api.d1v.ai`.
- You can override it in-app via `Settings → Profile → API`.
- `Copy diagnostics` includes the effective base URL, auth token presence/suffix, JWT claims (`sub/type/exp` when available), and last workspace status.

## Troubleshooting: Create Project returns 500

If project creation fails in `d1vai_app` but works in `d1vai` web:

- Open `Settings → Profile → API` and tap `Copy diagnostics`.
- Verify `effective_base_url` is `https://api.d1v.ai` and `auth_token_present=true`.
- Compare `jwt_sub` / `jwt_type` (or at least token suffix) with the token used in the web/curl request.

## Localization (l10n) workflow

- Source of truth: `lib/l10n/arb/app_*.arb`
- Generate runtime lookup table after edits:
  - `dart run tool/gen_l10n.dart`
- CI safeguard:
  - `test/l10n_arb_consistency_test.dart` fails if any locale is missing/adding keys vs `app_en.arb`.
