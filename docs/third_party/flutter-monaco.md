# flutter-monaco

Research checkout for evaluating Monaco-based editor architecture and performance tradeoffs.

## Source Repositories

- Fork repo: `git@github.com:d1vai/flutter_monaco.git`
- Original source repo: `git@github.com:omar-hanafy/flutter_monaco.git`
- Local checkout path in this app repo: `third_party/flutter_monaco`

## Tracking Model

- `third_party/flutter_monaco` is a standalone Git checkout used for analysis and upstream patch work.
- It is intentionally separate from the app's vendored `flutter-code-editor` source.
- `origin` should point to the `d1vai` fork.
- `upstream` should point to the original public repository.

## Current Status

### 2026-05-19

- Forked `omar-hanafy/flutter_monaco` into `d1vai/flutter_monaco`.
- Cloned the fork into `third_party/flutter_monaco`.
- Configured remotes:
  - `origin`: `git@github.com:d1vai/flutter_monaco.git`
  - `upstream`: `git@github.com:omar-hanafy/flutter_monaco.git`
- Current checkout used for evaluation:
  - Branch: `main`
  - Commit: `8f069951b12fc53f5836bf875f5504883ae21414`

## Notes

- This checkout is currently for architectural comparison and potential future adoption.
- The app does not depend on `flutter_monaco` at runtime yet.
