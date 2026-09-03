#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/docs/localized-screenshots"
OUTPUT_ROOT="${ROOT_DIR}/docs/store-assets-v2/app-store"
MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"

if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick (magick) is required." >&2
  exit 1
fi

declare -a devices=(
  "iphone-6.5|1284|2778"
  "ipad-13|2064|2752"
)
declare -a screens=(
  "01-home|home-screen.png"
  "02-terminal|terminal-screen.png"
  "03-community|community-screen.png"
  "04-profile|my-page-screen.png"
  "05-project|project-detail-screen.png"
  "06-chat|chat-with-ai-screen.png"
)

for device in "${devices[@]}"; do
  IFS='|' read -r device_path width height <<< "${device}"
  for locale_dir in "${SOURCE_DIR}"/*/; do
    locale="$(basename "${locale_dir%/}")"
    output_dir="${OUTPUT_ROOT}/${device_path}/screenshots/${locale}"
    mkdir -p "${output_dir}"
    for screen in "${screens[@]}"; do
      IFS='|' read -r name source <<< "${screen}"
      source_path="${locale_dir}/${source}"
      if [[ ! -f "${source_path}" ]]; then
        echo "Missing source screenshot: ${source_path}" >&2
        exit 1
      fi
      # Fit inside the device canvas instead of cropping the app chrome.
      "${MAGICK_BIN}" "${source_path}" -resize "${width}x${height}" \
        -background "#0b1328" -gravity center -extent "${width}x${height}" \
        "${output_dir}/${name}.png"
    done
  done
done

"${ROOT_DIR}/../.venv/bin/python" "${ROOT_DIR}/tool/generate_watch_companion_mockups.py"

echo "Exported iPhone/iPad captures and dedicated Watch companion mockups for $(find "${SOURCE_DIR}" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') locales."
