#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device_id="${1:-${D1V_E2E_DEVICE_ID:-}}"
require_full="${D1V_E2E_REQUIRE_FULL_MATRIX:-1}"

if [[ -z "${D1V_E2E_AUTH_TOKEN:-}" ]]; then
  echo "D1V_E2E_AUTH_TOKEN is required" >&2
  exit 2
fi
if [[ -z "${D1V_E2E_PROJECT_ID:-}" ]]; then
  echo "D1V_E2E_PROJECT_ID is required" >&2
  exit 2
fi
if [[ -z "${device_id}" ]]; then
  echo "A Flutter device id is required as argument 1 or D1V_E2E_DEVICE_ID" >&2
  exit 2
fi
if [[ "${require_full}" != "0" && "${require_full}" != "1" ]]; then
  echo "D1V_E2E_REQUIRE_FULL_MATRIX must be 0 or 1" >&2
  exit 2
fi
if [[ "${require_full}" == "1" ]]; then
  if [[ ! "${D1V_E2E_ORGANIZATION_ID:-}" =~ ^[1-9][0-9]*$ ]]; then
    echo "D1V_E2E_ORGANIZATION_ID is required for the full matrix" >&2
    exit 2
  fi
  if [[ -z "${D1V_E2E_SECONDARY_AUTH_TOKEN:-}" ]]; then
    echo "D1V_E2E_SECONDARY_AUTH_TOKEN is required for the full matrix" >&2
    exit 2
  fi
fi

defines_file="$(mktemp "${TMPDIR:-/tmp}/d1v-terminal-e2e.XXXXXX.json")"
cleanup() {
  if [[ -f "${defines_file}" ]]; then
    chmod 600 "${defines_file}" 2>/dev/null || true
    : > "${defines_file}"
    rm -f "${defines_file}"
  fi
}
trap cleanup EXIT INT TERM
chmod 600 "${defines_file}"

python3 - "${defines_file}" "${require_full}" <<'PY'
import json
import os
import sys

target, require_full = sys.argv[1:]
payload = {
    "D1V_E2E_AUTH_TOKEN": os.environ["D1V_E2E_AUTH_TOKEN"],
    "D1V_E2E_PROJECT_ID": os.environ["D1V_E2E_PROJECT_ID"],
    "D1V_E2E_ORGANIZATION_ID": os.environ.get("D1V_E2E_ORGANIZATION_ID", ""),
    "D1V_E2E_SECONDARY_AUTH_TOKEN": os.environ.get(
        "D1V_E2E_SECONDARY_AUTH_TOKEN", ""
    ),
    "D1V_E2E_API_BASE_URL": os.environ.get(
        "D1V_E2E_API_BASE_URL", "https://api.d1v.ai"
    ),
    "D1V_E2E_REQUIRE_FULL_MATRIX": require_full == "1",
}
with open(target, "w", encoding="utf-8") as output:
    json.dump(payload, output, separators=(",", ":"))
PY

cd "${repo_root}"
flutter test \
  integration_test/terminal_production_test.dart \
  -d "${device_id}" \
  --dart-define-from-file="${defines_file}"
