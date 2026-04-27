#!/bin/sh

set -e

REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"

if ! command -v flutter >/dev/null 2>&1; then
  brew install --cask flutter
fi

cd "${REPO_ROOT}"

flutter config --no-analytics
flutter --version
flutter precache --ios
flutter pub get

cd ios
pod install
