#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/terminal-production-e2e.yml"

if [[ ! -f "${workflow}" ]]; then
  echo "Missing terminal production E2E workflow" >&2
  exit 1
fi

ruby -r yaml - "${workflow}" <<'RUBY'
path = ARGV.fetch(0)
document = YAML.safe_load(File.read(path), aliases: false)

fail "workflow must be a mapping" unless document.is_a?(Hash)
triggers = document["on"] || document[true]
fail "workflow must only use workflow_dispatch" unless triggers.is_a?(Hash) && triggers.keys == ["workflow_dispatch"]

permissions = document["permissions"]
fail "workflow permissions must be contents: read" unless permissions == {"contents" => "read"}

concurrency = document["concurrency"]
unless concurrency == {"group" => "terminal-production-e2e", "cancel-in-progress" => false}
  fail "workflow must serialize production E2E without cancellation"
end

jobs = document.fetch("jobs")
fail "workflow must define one job" unless jobs.keys == ["full-production-matrix"]
job = jobs.fetch("full-production-matrix")
fail "workflow must use macos-latest" unless job["runs-on"] == "macos-latest"
timeout = job["timeout-minutes"]
fail "workflow timeout must be between 1 and 30 minutes" unless timeout.is_a?(Integer) && timeout.between?(1, 30)

environment = job.fetch("env")
expected_environment = {
  "CODE_SIGNING_ALLOWED" => "NO",
  "D1V_E2E_API_BASE_URL" => "https://api.d1v.ai",
  "D1V_E2E_REQUIRE_FULL_MATRIX" => "1",
  "D1V_E2E_AUTH_TOKEN" => "${{ secrets.D1V_E2E_AUTH_TOKEN }}",
  "D1V_E2E_PROJECT_ID" => "${{ secrets.D1V_E2E_PROJECT_ID }}",
  "D1V_E2E_ORGANIZATION_ID" => "${{ secrets.D1V_E2E_ORGANIZATION_ID }}",
  "D1V_E2E_SECONDARY_AUTH_TOKEN" => "${{ secrets.D1V_E2E_SECONDARY_AUTH_TOKEN }}",
}
fail "workflow environment does not match the production matrix" unless environment == expected_environment

steps = job.fetch("steps")
fail "workflow must define steps" unless steps.is_a?(Array) && !steps.empty?
uses = steps.map { |step| step["uses"] }.compact
if uses.any? { |action| action.include?("upload-artifact") }
  fail "production E2E must not upload artifacts"
end

checkout = steps.find { |step| step["uses"] == "actions/checkout@v6" }
fail "workflow must use the pinned checkout major" unless checkout
checkout_options = checkout.fetch("with", {})
fail "checkout credentials must not persist" unless checkout_options["persist-credentials"] == false

runs = steps.map { |step| step["run"] }.compact
fail "workflow must reject non-main refs" unless runs.any? { |run| run.include?('refs/heads/main') }
if runs.any? { |run| run.include?("secrets.") }
  fail "workflow must not interpolate secrets into shell commands"
end
if runs.any? { |run| run.match?(/(^|\s)set\s+-x(\s|$)/) }
  fail "workflow must not enable command tracing"
end

launcher_command = "bash tool/run_terminal_production_e2e.sh macos"
fail "workflow must invoke the secret-safe launcher exactly once" unless runs.count { |run| run == launcher_command } == 1
RUBY

echo "terminal production E2E workflow checks passed"
