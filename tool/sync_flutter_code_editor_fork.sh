#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/third_party/flutter-code-editor"
FORK_REPO="git@github.com:d1vai/flutter-code-editor.git"
BRANCH="${SYNC_BRANCH:-main}"
COMMIT_MESSAGE="${1:-chore: sync vendored flutter_code_editor from d1vai_app}"

if [[ ! -d "$VENDOR_DIR" ]]; then
  echo "Vendor directory not found: $VENDOR_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git clone --branch "$BRANCH" "$FORK_REPO" "$TMP_DIR/repo" >/dev/null 2>&1

rsync -a --delete \
  --exclude '.git' \
  --exclude '.dart_tool' \
  --exclude 'build' \
  "$VENDOR_DIR"/ "$TMP_DIR/repo"/

cd "$TMP_DIR/repo"

if [[ -z "$(git status --short)" ]]; then
  echo "No fork changes to sync."
  exit 0
fi

git add -A
git commit -m "$COMMIT_MESSAGE"
git push origin "$BRANCH"

echo "Synced vendored flutter-code-editor to d1vai/flutter-code-editor:$BRANCH"
