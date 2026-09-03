#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_ROOT="${ROOT_DIR}/docs/store-assets-v2/app-store"
MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"

if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick (magick) is required." >&2
  exit 1
fi

declare -a devices=(
  "iphone-6.5|1284|2778|48"
  "ipad-13|2064|2752|64"
  "apple-watch/ultra-3-422x514|422|514|18"
)
declare -a screens=(01-home 02-terminal 03-community 04-profile 05-project 06-chat)

for device in "${devices[@]}"; do
  IFS='|' read -r device_path width height pointsize <<< "${device}"
  source_root="${ASSET_ROOT}/${device_path}/screenshots"
  for locale_dir in "${source_root}"/*/; do
    locale="$(basename "${locale_dir%/}")"
    promo_dir="${ASSET_ROOT}/${device_path}/promos/${locale}"
    mkdir -p "${promo_dir}"
    for screen in "${screens[@]}"; do
      source="${locale_dir}/${screen}.png"
      [[ -f "${source}" ]] || { echo "Missing ${source}" >&2; exit 1; }
      "${MAGICK_BIN}" "${source}" \
        -fill "#0b1328cc" -draw "rectangle 0,0 ${width},$((pointsize * 2))" \
        -gravity north -fill white -font "/System/Library/Fonts/Avenir Next.ttc" \
        -pointsize "${pointsize}" -annotate "+0+$((pointsize / 3))" "d1v.ai - ${locale}" \
        "${promo_dir}/${screen}-promo.png"
    done
    "${MAGICK_BIN}" \
      "${promo_dir}/01-home-promo.png" "${promo_dir}/02-terminal-promo.png" \
      "${promo_dir}/03-community-promo.png" "${promo_dir}/04-profile-promo.png" \
      "${promo_dir}/05-project-promo.png" "${promo_dir}/06-chat-promo.png" \
      +append "${promo_dir}/preview-strip.png"
  done
done

echo "Generated App Store promo posters and preview strips from localized device screenshots."
