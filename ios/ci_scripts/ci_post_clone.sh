#!/bin/sh

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}}"
FLUTTER_ROOT="${HOME}/flutter"
GENERATED_XCCONFIG="${REPO_ROOT}/ios/Flutter/Generated.xcconfig"
FLUTTER_EXPORT_ENV="${REPO_ROOT}/ios/Flutter/flutter_export_environment.sh"

encode_define() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

append_dart_define() {
  key="$1"
  value="$2"

  if [ -z "$value" ]; then
    return
  fi

  encoded="$(encode_define "${key}=${value}")"
  if [ -n "${EXTRA_DART_DEFINES}" ]; then
    EXTRA_DART_DEFINES="${EXTRA_DART_DEFINES},${encoded}"
  else
    EXTRA_DART_DEFINES="${encoded}"
  fi
}

merge_dart_defines_into_file() {
  file_path="$1"

  if [ ! -f "${file_path}" ] || [ -z "${EXTRA_DART_DEFINES}" ]; then
    return
  fi

  python3 - "${file_path}" "${EXTRA_DART_DEFINES}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
extra = sys.argv[2]
content = path.read_text()
lines = content.splitlines()
existing = ""
for i, line in enumerate(lines):
    if line.startswith("DART_DEFINES="):
        existing = line[len("DART_DEFINES="):].strip('"')
        merged = f"{existing},{extra}" if existing else extra
        lines[i] = f"DART_DEFINES={merged}"
        break
    if line.startswith('export "DART_DEFINES=') and line.endswith('"'):
        existing = line[len('export "DART_DEFINES='):-1]
        merged = f"{existing},{extra}" if existing else extra
        lines[i] = f'export "DART_DEFINES={merged}"'
        break
else:
    merged = extra
    lines.append(f'export "DART_DEFINES={merged}"' if path.name == "flutter_export_environment.sh" else f"DART_DEFINES={merged}")
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

cd "${REPO_ROOT}"

flutter config --no-analytics
flutter --version
flutter precache --ios
flutter pub get

append_dart_define "STRIPE_PUBLISHABLE_KEY" "${STRIPE_PUBLISHABLE_KEY:-}"
append_dart_define "STRIPE_MERCHANT_IDENTIFIER" "${STRIPE_MERCHANT_IDENTIFIER:-}"
append_dart_define "STRIPE_MERCHANT_DISPLAY_NAME" "${STRIPE_MERCHANT_DISPLAY_NAME:-}"
append_dart_define "STRIPE_MERCHANT_COUNTRY_CODE" "${STRIPE_MERCHANT_COUNTRY_CODE:-}"
append_dart_define "STRIPE_RETURN_URL" "${STRIPE_RETURN_URL:-}"

merge_dart_defines_into_file "${GENERATED_XCCONFIG}"
merge_dart_defines_into_file "${FLUTTER_EXPORT_ENV}"

cd ios
pod install
