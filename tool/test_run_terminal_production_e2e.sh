#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="${repo_root}/tool/run_terminal_production_e2e.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/d1v-terminal-launcher-test.XXXXXX")"
trap 'rm -rf "${fixture_root}"' EXIT INT TERM

expect_rejected() {
  local expected_message="$1"
  shift
  local output
  local result_code
  set +e
  output="$(env "$@" bash "${launcher}" 2>&1)"
  result_code=$?
  set -e
  [[ "${result_code}" -eq 2 ]]
  [[ "${output}" == *"${expected_message}"* ]]
  [[ "${output}" != *"fixture-primary-secret"* ]]
  [[ "${output}" != *"fixture-secondary-secret"* ]]
}

expect_rejected \
  "D1V_E2E_AUTH_TOKEN is required" \
  -u D1V_E2E_AUTH_TOKEN \
  -u D1V_E2E_PROJECT_ID \
  D1V_E2E_DEVICE_ID=test-device

expect_rejected \
  "D1V_E2E_PROJECT_ID is required" \
  D1V_E2E_AUTH_TOKEN=fixture-primary-secret \
  -u D1V_E2E_PROJECT_ID \
  D1V_E2E_DEVICE_ID=test-device

expect_rejected \
  "A Flutter device id is required" \
  D1V_E2E_AUTH_TOKEN=fixture-primary-secret \
  D1V_E2E_PROJECT_ID=fixture-project \
  -u D1V_E2E_DEVICE_ID

expect_rejected \
  "D1V_E2E_ORGANIZATION_ID is required" \
  D1V_E2E_AUTH_TOKEN=fixture-primary-secret \
  D1V_E2E_PROJECT_ID=fixture-project \
  D1V_E2E_DEVICE_ID=test-device \
  D1V_E2E_REQUIRE_FULL_MATRIX=1 \
  -u D1V_E2E_ORGANIZATION_ID

expect_rejected \
  "D1V_E2E_SECONDARY_AUTH_TOKEN is required" \
  D1V_E2E_AUTH_TOKEN=fixture-primary-secret \
  D1V_E2E_PROJECT_ID=fixture-project \
  D1V_E2E_DEVICE_ID=test-device \
  D1V_E2E_REQUIRE_FULL_MATRIX=1 \
  D1V_E2E_ORGANIZATION_ID=42 \
  -u D1V_E2E_SECONDARY_AUTH_TOKEN

capture_file="${fixture_root}/defines-path"
stub_flutter="${fixture_root}/flutter"
cat > "${stub_flutter}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

defines_path=""
device_seen=false
test_path_seen=false
for argument in "$@"; do
  [[ "${argument}" != *"${D1V_E2E_AUTH_TOKEN}"* ]]
  [[ "${argument}" != *"${D1V_E2E_SECONDARY_AUTH_TOKEN:-}"* || -z "${D1V_E2E_SECONDARY_AUTH_TOKEN:-}" ]]
  case "${argument}" in
    --dart-define-from-file=*) defines_path="${argument#*=}" ;;
    test-device) device_seen=true ;;
    integration_test/terminal_production_test.dart) test_path_seen=true ;;
  esac
done

[[ "${device_seen}" == true ]]
[[ "${test_path_seen}" == true ]]
[[ -n "${defines_path}" && -f "${defines_path}" ]]
python3 - "${defines_path}" <<'PY'
import json
import os
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    payload = json.load(source)
assert payload["D1V_E2E_AUTH_TOKEN"] == os.environ["D1V_E2E_AUTH_TOKEN"]
assert payload["D1V_E2E_PROJECT_ID"] == os.environ["D1V_E2E_PROJECT_ID"]
assert payload["D1V_E2E_ORGANIZATION_ID"] == os.environ.get(
    "D1V_E2E_ORGANIZATION_ID", ""
)
assert payload["D1V_E2E_SECONDARY_AUTH_TOKEN"] == os.environ.get(
    "D1V_E2E_SECONDARY_AUTH_TOKEN", ""
)
expected_full = os.environ.get("D1V_E2E_REQUIRE_FULL_MATRIX", "1") == "1"
assert payload["D1V_E2E_REQUIRE_FULL_MATRIX"] is expected_full
PY
printf '%s' "${defines_path}" > "${D1V_E2E_STUB_CAPTURE}"
SH
chmod +x "${stub_flutter}"

run_success_case() {
  local require_full="$1"
  shift
  : > "${capture_file}"
  local output
  output="$(
    PATH="${fixture_root}:${PATH}" \
    D1V_E2E_STUB_CAPTURE="${capture_file}" \
    D1V_E2E_AUTH_TOKEN=fixture-primary-secret \
    D1V_E2E_PROJECT_ID=fixture-project \
    D1V_E2E_REQUIRE_FULL_MATRIX="${require_full}" \
    "$@" \
    bash "${launcher}" test-device 2>&1
  )"
  [[ "${output}" != *"fixture-primary-secret"* ]]
  [[ "${output}" != *"fixture-secondary-secret"* ]]
  local defines_path
  defines_path="$(<"${capture_file}")"
  [[ -n "${defines_path}" ]]
  [[ ! -e "${defines_path}" ]]
}

run_success_case 0 env \
  -u D1V_E2E_ORGANIZATION_ID \
  -u D1V_E2E_SECONDARY_AUTH_TOKEN

run_success_case 1 env \
  D1V_E2E_ORGANIZATION_ID=42 \
  D1V_E2E_SECONDARY_AUTH_TOKEN=fixture-secondary-secret

echo "terminal production launcher checks passed"
