#!/bin/sh

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}}"
FLUTTER_ROOT="${HOME}/flutter"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${FLUTTER_ROOT}"
  fi
  export PATH="${FLUTTER_ROOT}/bin:${PATH}"
fi

cd "${REPO_ROOT}"

flutter config --no-analytics
flutter --version
flutter precache --ios
flutter pub get

cd ios
pod install
