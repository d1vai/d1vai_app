#!/bin/sh

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}}"
FLUTTER_ROOT="${HOME}/flutter"
GENERATED_XCCONFIG="${REPO_ROOT}/macos/Flutter/ephemeral/Flutter-Generated.xcconfig"
FLUTTER_EXPORT_ENV="${REPO_ROOT}/macos/Flutter/ephemeral/flutter_export_environment.sh"

encode_define() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

append_dart_define() {
  key="$1"
  value="$2"
  [ -n "$value" ] || return 0
  encoded="$(encode_define "${key}=${value}")"
  EXTRA_DART_DEFINES="${EXTRA_DART_DEFINES:+${EXTRA_DART_DEFINES},}${encoded}"
}

merge_dart_defines() {
  file_path="$1"
  [ -f "$file_path" ] && [ -n "$EXTRA_DART_DEFINES" ] || return 0
  python3 - "$file_path" "$EXTRA_DART_DEFINES" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
extra = sys.argv[2]
lines = path.read_text().splitlines()
for index, line in enumerate(lines):
    if line.startswith("DART_DEFINES="):
        current = line.removeprefix("DART_DEFINES=").strip('"')
        lines[index] = f"DART_DEFINES={current + ',' if current else ''}{extra}"
        break
    if line.startswith('export "DART_DEFINES=') and line.endswith('"'):
        current = line[len('export "DART_DEFINES='):-1]
        lines[index] = f'export "DART_DEFINES={current + "," if current else ""}{extra}"'
        break
else:
    prefix = 'export "DART_DEFINES=' if path.name.endswith('.sh') else 'DART_DEFINES='
    suffix = '"' if path.name.endswith('.sh') else ''
    lines.append(f"{prefix}{extra}{suffix}")
path.write_text("\n".join(lines) + "\n")
PY
}

EXTRA_DART_DEFINES=""

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${FLUTTER_ROOT}"
  fi
  export PATH="${FLUTTER_ROOT}/bin:${PATH}"
fi

cd "$REPO_ROOT"
flutter config --no-analytics --enable-macos-desktop
flutter --version
flutter precache --macos
rm -rf macos/Pods macos/.symlinks macos/Podfile.lock macos/Flutter/ephemeral
flutter pub get
flutter build macos --config-only --release

append_dart_define STRIPE_PUBLISHABLE_KEY "${STRIPE_PUBLISHABLE_KEY:-}"
append_dart_define AMPLITUDE_API_KEY "${AMPLITUDE_API_KEY:-}"
append_dart_define STRIPE_MERCHANT_IDENTIFIER "${STRIPE_MERCHANT_IDENTIFIER:-}"
append_dart_define STRIPE_MERCHANT_DISPLAY_NAME "${STRIPE_MERCHANT_DISPLAY_NAME:-}"
append_dart_define STRIPE_MERCHANT_COUNTRY_CODE "${STRIPE_MERCHANT_COUNTRY_CODE:-}"
append_dart_define STRIPE_RETURN_URL "${STRIPE_RETURN_URL:-}"

merge_dart_defines "$GENERATED_XCCONFIG"
merge_dart_defines "$FLUTTER_EXPORT_ENV"

cd macos
pod install --repo-update
