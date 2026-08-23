#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

terminal_files=(
  lib/controllers/terminal_session_controller.dart
  lib/models/shell_session.dart
  lib/router/app_router.dart
  lib/screens/main_screen.dart
  lib/screens/terminal_screen.dart
  lib/services/shell_session_api.dart
  lib/services/terminal_protocol.dart
  lib/services/terminal_transport.dart
  lib/services/workspace_service.dart
  lib/widgets/terminal/terminal_mobile_keys.dart
  lib/widgets/terminal/terminal_output_highlighter.dart
  lib/widgets/terminal/terminal_output_pump.dart
  lib/widgets/terminal/terminal_project_picker.dart
  lib/widgets/terminal/terminal_status_overlay.dart
  lib/widgets/terminal/terminal_surface.dart
  lib/widgets/terminal/terminal_theme.dart
  test/api_client_test.dart
  test/shell_session_api_test.dart
  test/terminal_mobile_keys_test.dart
  test/terminal_output_highlighter_test.dart
  test/terminal_output_pump_test.dart
  test/terminal_project_picker_test.dart
  test/terminal_protocol_test.dart
  test/terminal_session_controller_test.dart
  test/terminal_surface_test.dart
  test/terminal_transport_test.dart
  test/workspace_organization_scope_test.dart
  integration_test/terminal_performance_test.dart
  integration_test/terminal_production_test.dart
  integration_test/terminal_smoke_test.dart
  test_driver/integration_test.dart
)

shell_files=(
  tool/run_terminal_production_e2e.sh
  tool/test_run_terminal_production_e2e.sh
  tool/verify_terminal_release.sh
)

for required_file in \
  "${terminal_files[@]}" \
  "${shell_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing terminal release input: ${required_file}" >&2
    exit 1
  fi
done

dart format --output=none --set-exit-if-changed "${terminal_files[@]}"
flutter analyze "${terminal_files[@]}"

bash -n "${shell_files[@]}"
bash tool/test_run_terminal_production_e2e.sh

if rg -n \
  'auth_token_(len|suffix)|Auth: present.*(kind|len|suffix)|suffix=\$tokenSuffix' \
  lib integration_test; then
  echo "Authentication fingerprint logging is forbidden" >&2
  exit 1
fi

flutter test

device_id="${D1V_TERMINAL_RELEASE_DEVICE_ID:-}"
if [[ -n "${device_id}" ]]; then
  flutter test integration_test/terminal_smoke_test.dart -d "${device_id}"
  flutter test integration_test/terminal_production_test.dart -d "${device_id}"
  flutter drive \
    --profile \
    -d "${device_id}" \
    --driver test_driver/integration_test.dart \
    --target integration_test/terminal_performance_test.dart
fi

echo "Flutter terminal release gate passed"
