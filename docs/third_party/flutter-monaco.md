# flutter-monaco

Local third-party editor checkout used directly by `d1vai_app` during development.

## Source Repositories

- Fork repo: `git@github.com:d1vai/flutter_monaco.git`
- Original source repo: `git@github.com:omar-hanafy/flutter_monaco.git`
- Local checkout path in this app repo: `third_party/flutter_monaco`

## Tracking Model

- `d1vai_app` depends on `flutter_monaco` through a local path dependency:
  - `third_party/flutter_monaco`
- `third_party/flutter_monaco` is tracked in `d1vai_app` as a Git submodule.
- Local development should edit that checkout directly.
- CI checks out Git submodules before `flutter pub get`.

## Development Rules

1. Make Monaco changes under `third_party/flutter_monaco`.
2. Commit and push those changes to `d1vai/flutter_monaco`.
3. Run `flutter pub get` in `d1vai_app` so `pubspec.lock` records the local package state.
4. Commit the app-side integration changes in `d1vai_app`.

## Sync Command

Use:

```bash
tool/sync_flutter_monaco_fork.sh "your commit message"
```

This helper commits and pushes the local `third_party/flutter_monaco` checkout when needed, then refreshes `d1vai_app` package resolution.

## CI Note

- GitHub Actions checks out submodules recursively so `third_party/flutter_monaco` is present before `flutter pub get`.

## Patch Log

### 2026-05-19

- Forked `omar-hanafy/flutter_monaco` into `d1vai/flutter_monaco`.
- Adopted `third_party/flutter_monaco` as the app's local path dependency.
- Added CI bootstrap so Actions checks out the forked submodule into the expected local path.
