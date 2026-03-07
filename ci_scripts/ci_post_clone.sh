#!/bin/sh
set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Xcode Cloud images may not have Flutter in PATH.
if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$PATH:$HOME/flutter/bin"
fi

flutter --version
flutter precache --ios
flutter pub get

cd ios
pod install
