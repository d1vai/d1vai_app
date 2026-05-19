#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MONACO_DIR="$ROOT_DIR/third_party/flutter_monaco"
BRANCH="${SYNC_BRANCH:-main}"
COMMIT_MESSAGE="${1:-chore: sync local flutter_monaco checkout}"

if [[ ! -d "$MONACO_DIR/.git" ]]; then
  echo "Local flutter_monaco checkout not found at: $MONACO_DIR" >&2
  exit 1
fi

cd "$MONACO_DIR"

if [[ -n "$(git status --short)" ]]; then
  git add -A
  git commit -m "$COMMIT_MESSAGE"
  git push origin "$BRANCH"
else
  echo "No flutter_monaco changes to sync."
fi

cd "$ROOT_DIR"
flutter pub get

echo "flutter_monaco synced and d1vai_app package resolution refreshed."
