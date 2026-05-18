# flutter-code-editor

Third-party editor fork tracked for `d1vai` customization work.

## Repositories

- Upstream: `git@github.com:akvelon/flutter-code-editor.git`
- Fork: `git@github.com:d1vai/flutter-code-editor.git`
- Local clone: `third_party/flutter-code-editor`

## Current Local State

- Default branch: `main`
- Checked out commit: `bad3c52`
- Upstream remote configured locally as `upstream`

## Customization Policy

- Keep upstream history intact in the fork.
- Put `d1vai`-specific patches on dedicated branches or clearly labeled commits.
- Record every behavior change here before shipping it into the app.
- Prefer consuming the fork through a git dependency or a path dependency during active development.

## Suggested Workflow

1. Fetch upstream in `third_party/flutter-code-editor`.
2. Merge or rebase from `upstream/main` into the fork branch you are using.
3. Implement `d1vai` changes in the fork repo, not in copied source under `lib/`.
4. Update this file with:
   - changed files
   - purpose of the patch
   - upstreamability decision
   - app integration status

## Planned Customization Log

No `d1vai`-specific patches recorded yet.
