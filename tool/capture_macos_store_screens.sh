#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_ROOT="${ROOT_DIR}/docs/store-assets-v3/app-store/macos/screenshots"
TMP_ROOT="$(mktemp -d)"
PYTHON_BIN="${PYTHON_BIN:-${ROOT_DIR}/../.venv/bin/python}"
trap 'rm -rf "${TMP_ROOT}"' EXIT

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "Python environment not found or not executable: ${PYTHON_BIN}" >&2
  echo "Set PYTHON_BIN to an interpreter with selenium and requests installed." >&2
  exit 1
fi

LOCALES=(
  en da uk ru hu hi id tr bn he el de it nb cs ja fr pl th sv zh zh_Hant
  ro fi nl pt_BR pt_PT es vi ar ko ms
)

"${PYTHON_BIN}" "${ROOT_DIR}/tool/capture_store_screens.py" \
  --all-languages \
  --fast \
  --skip-chat-seed \
  --content-wait-seconds 2 \
  --viewport-width 1440 \
  --viewport-height 900 \
  --device-scale-factor 1 \
  --output-dir "${TMP_ROOT}"

declare -a SOURCES=(
  home-screen.png terminal-screen.png community-screen.png my-page-screen.png
  project-detail-screen.png chat-with-ai-screen.png
)
declare -a TARGETS=(
  01-home.png 02-terminal.png 03-community.png 04-profile.png
  05-project.png 06-chat.png
)

for locale in "${LOCALES[@]}"; do
  locale_dir="${OUT_ROOT}/${locale}"
  mkdir -p "${locale_dir}"
  for index in "${!SOURCES[@]}"; do
    cp "${TMP_ROOT}/${locale}/${SOURCES[$index]}" "${locale_dir}/${TARGETS[$index]}"
  done
done

echo "Captured ${#LOCALES[@]} localized macOS screenshot sets under ${OUT_ROOT}"
