# flutter-code-editor

Vendored third-party editor source tracked inside this repository.

## Source Repositories

- Fork repo: `git@github.com:d1vai/flutter-code-editor.git`
- Original source repo: `git@github.com:akvelon/flutter-code-editor.git`
- Vendored path in this app: `third_party/flutter-code-editor`

## Tracking Model

- The source under `third_party/flutter-code-editor` is committed directly in `d1vai_app`.
- This is intentionally not a nested Git repository.
- When we patch vendored editor code, the app repo and the fork repo should both be updated.

## Update Rules

1. Make editor changes under `third_party/flutter-code-editor`.
2. Commit the vendored changes in `d1vai_app`.
3. Push the same vendored content back to `d1vai/flutter-code-editor`.
4. Record the reason for the patch here.

## Sync Command

Use:

```bash
tool/sync_flutter_code_editor_fork.sh "your commit message"
```

This script clones `d1vai/flutter-code-editor`, copies the vendored source from this app repo, commits if needed, and pushes to the fork.

## Patch Log

### 2026-05-19

- Switched `d1vai_app` code editor integration from plain `TextField` to vendored `flutter_code_editor`.
- Added local path dependency on `third_party/flutter-code-editor`.
- No fork-only patch has been applied to the vendored package yet.
