#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/docs/readme-assets"
OUT_DIR="${ROOT_DIR}/docs/store-assets"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"
if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick not found. Install 'magick' first." >&2
  exit 1
fi

DISPLAY_FONT="/System/Library/Fonts/Avenir Next.ttc"
DISPLAY_FONT_BOLD="/System/Library/Fonts/Avenir Next.ttc"
BODY_FONT="/System/Library/Fonts/SFNS.ttf"
BODY_FONT_BOLD="/System/Library/Fonts/SFNS.ttf"
APP_ICON="${ROOT_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"

for required in \
  "${SRC_DIR}/projects-screen.png" \
  "${SRC_DIR}/community-screen.png" \
  "${SRC_DIR}/docs-screen.png" \
  "${SRC_DIR}/app-overview.png" \
  "${APP_ICON}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing required asset: ${required}" >&2
    exit 1
  fi
done

mkdir -p \
  "${OUT_DIR}/app-store/iphone-6.9" \
  "${OUT_DIR}/app-store/ipad-13" \
  "${OUT_DIR}/google-play/phone" \
  "${OUT_DIR}/google-play/tablet-7" \
  "${OUT_DIR}/google-play/tablet-10" \
  "${OUT_DIR}/promo" \
  "${OUT_DIR}/masters/phone" \
  "${OUT_DIR}/masters/ipad"

slides=(
  "projects|projects-screen.png|Build with AI from your phone|Create projects, import repos, and keep active work moving from one mobile workspace."
  "community|community-screen.png|See what your team ships|Browse community output, share work, and stay close to live product momentum."
  "docs|docs-screen.png|Find context without losing flow|Open docs, workflows, and implementation references exactly when you need them."
  "overview|app-overview.png|Inspect, operate, and move faster|Projects, docs, community, and operations stay connected inside one serious mobile control plane."
)

render_text_block() {
  local width="$1"
  local height="$2"
  local font="$3"
  local pointsize="$4"
  local fill="$5"
  local gravity="$6"
  local text="$7"
  local output="$8"

  "${MAGICK_BIN}" -background none -fill "${fill}" -font "${font}" -pointsize "${pointsize}" \
    -size "${width}x${height}" -gravity "${gravity}" caption:"${text}" "${output}"
}

build_base() {
  local width="$1"
  local height="$2"
  local out="$3"
  local cache="${TMP_DIR}/base-${width}x${height}.png"

  if [[ ! -f "${cache}" ]]; then
    "${MAGICK_BIN}" -size "${width}x${height}" xc:"#091224" \
      \( -size "${width}x${height}" radial-gradient:"#111e3c-#08101f" \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -fill "rgba(105,99,255,0.22)" -draw "circle $((width / 4)),$((height / 7)) $((width / 4 + width / 8)),$((height / 7))" -blur 0x45 \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -fill "rgba(255,71,149,0.10)" -draw "circle $((width - width / 5)),$((height - height / 4)) $((width - width / 10)),$((height - height / 4))" -blur 0x55 \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -stroke "rgba(255,255,255,0.05)" -strokewidth 2 -draw "line 0,$((height * 28 / 100)) ${width},$((height * 28 / 100))" \) -compose over -composite \
      "${cache}"
  fi

  cp "${cache}" "${out}"
}

build_badge() {
  local width="$1"
  local height="$2"
  local text="$3"
  local out="$4"
  local icon_size=$((height - 18))

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(255,255,255,0.08)" -stroke "rgba(255,255,255,0.10)" -strokewidth 1 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) $((height / 2)),$((height / 2))" \
    "${TMP_DIR}/badge-base.png"

  "${MAGICK_BIN}" "${APP_ICON}" -resize "${icon_size}x${icon_size}" "${TMP_DIR}/badge-icon.png"

  render_text_block $((width - icon_size - 34)) "${height}" "${BODY_FONT_BOLD}" $((height / 2 - 4)) "#d9def7" west "${text}" "${TMP_DIR}/badge-text.png"

  "${MAGICK_BIN}" "${TMP_DIR}/badge-base.png" \
    "${TMP_DIR}/badge-icon.png" -gravity west -geometry +10+0 -composite \
    "${TMP_DIR}/badge-text.png" -gravity west -geometry +$((icon_size + 20))+0 -composite \
    "${out}"
}

build_card() {
  local source="$1"
  local width="$2"
  local height="$3"
  local radius="$4"
  local out="$5"

  "${MAGICK_BIN}" "${source}" -resize "$((width - 64))x$((height - 64))>" "${TMP_DIR}/card-source.png"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "#111a32" -stroke "rgba(255,255,255,0.08)" -strokewidth 2 \
    -draw "roundrectangle 1,1 $((width - 2)),$((height - 2)) ${radius},${radius}" \
    "${TMP_DIR}/card-shell.png"

  "${MAGICK_BIN}" -size "$((width - 36))x$((height - 36))" xc:black \
    -fill white -draw "roundrectangle 0,0 $((width - 37)),$((height - 37)) $((radius - 12)),$((radius - 12))" \
    "${TMP_DIR}/card-mask.png"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(255,255,255,0.03)" \
    -draw "roundrectangle 1,1 $((width - 2)),$((height - 2)) ${radius},${radius}" \
    "${TMP_DIR}/card-gloss.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-shell.png" \
    "${TMP_DIR}/card-source.png" -gravity center -composite \
    "${TMP_DIR}/card-gloss.png" -gravity center -composite \
    "${TMP_DIR}/card-composite.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-composite.png" "${TMP_DIR}/card-mask.png" \
    -gravity center -geometry +0+0 -compose copy_opacity -composite \
    "${TMP_DIR}/card-masked.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-masked.png" \
    \( +clone -background "rgba(0,0,0,0.82)" -shadow 55x18+0+20 \) \
    +swap -background none -layers merge +repage "${TMP_DIR}/card-shadow.png"

  mv "${TMP_DIR}/card-shadow.png" "${out}"
}

build_store_shot() {
  local canvas_w="$1"
  local canvas_h="$2"
  local badge_label="$3"
  local headline="$4"
  local body="$5"
  local source="$6"
  local out="$7"
  local badge_w="$8"
  local badge_h="$9"
  local headline_w="${10}"
  local headline_h="${11}"
  local body_w="${12}"
  local body_h="${13}"
  local card_w="${14}"
  local card_h="${15}"
  local card_y="${16}"
  local text_x="${17}"
  local badge_x="${18}"
  local headline_y="${19}"
  local body_y="${20}"

  build_base "${canvas_w}" "${canvas_h}" "${TMP_DIR}/base.png"
  build_badge "${badge_w}" "${badge_h}" "${badge_label}" "${TMP_DIR}/badge.png"
  render_text_block "${headline_w}" "${headline_h}" "${DISPLAY_FONT_BOLD}" $((canvas_w / 19)) "#f3f5ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text_block "${body_w}" "${body_h}" "${BODY_FONT}" $((canvas_w / 34)) "#c1cae8" west "${body}" "${TMP_DIR}/body.png"
  build_card "${source}" "${card_w}" "${card_h}" $((canvas_w / 20)) "${TMP_DIR}/card.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/badge.png" -gravity north -geometry "+${badge_x}+92" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+${text_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+${text_x}+${body_y}" -composite \
    "${TMP_DIR}/card.png" -gravity north -geometry "+0+${card_y}" -composite \
    -background "#091224" -alpha remove -alpha off \
    "${out}"
}

build_feature_graphic() {
  local out="$1"

  build_base 1024 500 "${TMP_DIR}/feature-base.png"

  build_card "${SRC_DIR}/projects-screen.png" 170 340 28 "${TMP_DIR}/fg-projects.png"
  build_card "${SRC_DIR}/community-screen.png" 170 340 28 "${TMP_DIR}/fg-community.png"
  build_card "${SRC_DIR}/docs-screen.png" 170 340 28 "${TMP_DIR}/fg-docs.png"

  build_badge 228 46 "d1v.ai mobile" "${TMP_DIR}/feature-badge.png"
  render_text_block 420 170 "${DISPLAY_FONT_BOLD}" 34 "#f4f6ff" west "Build, inspect, and operate AI-native projects anywhere." "${TMP_DIR}/feature-headline.png"
  render_text_block 420 90 "${BODY_FONT}" 18 "#c0cae8" west "Projects, docs, community, and operations in one serious mobile workspace." "${TMP_DIR}/feature-body.png"

  "${MAGICK_BIN}" "${TMP_DIR}/feature-base.png" \
    "${TMP_DIR}/feature-badge.png" -gravity northwest -geometry +60+48 -composite \
    "${TMP_DIR}/feature-headline.png" -gravity northwest -geometry +60+112 -composite \
    "${TMP_DIR}/feature-body.png" -gravity northwest -geometry +62+282 -composite \
    "${TMP_DIR}/fg-projects.png" -gravity northeast -geometry +274+118 -composite \
    "${TMP_DIR}/fg-community.png" -gravity northeast -geometry +144+72 -composite \
    "${TMP_DIR}/fg-docs.png" -gravity northeast -geometry +22+118 -composite \
    -background "#091224" -alpha remove -alpha off \
    "${out}"
}

resize_fill() {
  local source="$1"
  local width="$2"
  local height="$3"
  local out="$4"

  "${MAGICK_BIN}" "${source}" \
    -resize "${width}x${height}^" \
    -gravity center \
    -crop "${width}x${height}+0+0" +repage \
    "${out}"
}

resize_fit() {
  local source="$1"
  local width="$2"
  local height="$3"
  local out="$4"

  "${MAGICK_BIN}" "${source}" -resize "${width}x${height}!" "${out}"
}

build_promo_poster() {
  local out="$1"

  build_base 1600 2000 "${TMP_DIR}/poster-base.png"
  build_badge 310 62 "d1v.ai mobile workspace" "${TMP_DIR}/poster-badge.png"
  render_text_block 1240 260 "${DISPLAY_FONT_BOLD}" 86 "#f4f6ff" west "A serious mobile control plane for AI-native teams." "${TMP_DIR}/poster-headline.png"
  render_text_block 1140 120 "${BODY_FONT}" 34 "#c0cae8" west "Create projects, inspect context, monitor operations, and stay in flow away from desktop." "${TMP_DIR}/poster-body.png"
  build_card "${SRC_DIR}/projects-screen.png" 392 852 42 "${TMP_DIR}/poster-projects.png"
  build_card "${SRC_DIR}/community-screen.png" 392 852 42 "${TMP_DIR}/poster-community.png"
  build_card "${SRC_DIR}/docs-screen.png" 392 852 42 "${TMP_DIR}/poster-docs.png"

  "${MAGICK_BIN}" "${TMP_DIR}/poster-base.png" \
    "${TMP_DIR}/poster-badge.png" -gravity north -geometry -584+116 -composite \
    "${TMP_DIR}/poster-headline.png" -gravity north -geometry -124+222 -composite \
    "${TMP_DIR}/poster-body.png" -gravity north -geometry -170+514 -composite \
    "${TMP_DIR}/poster-projects.png" -gravity south -geometry -440+154 -composite \
    "${TMP_DIR}/poster-community.png" -gravity south -geometry +0+90 -composite \
    "${TMP_DIR}/poster-docs.png" -gravity south -geometry +440+154 -composite \
    -background "#091224" -alpha remove -alpha off \
    "${out}"
}

while IFS='|' read -r slug source_file headline body; do
  source_path="${SRC_DIR}/${source_file}"

  build_store_shot \
    1440 2560 \
    "d1v.ai mobile" \
    "${headline}" \
    "${body}" \
    "${source_path}" \
    "${OUT_DIR}/masters/phone/${slug}.png" \
    286 56 1120 250 1060 148 1180 1480 846 130 130 212 468

  build_store_shot \
    2064 2752 \
    "d1v.ai mobile" \
    "${headline}" \
    "${body}" \
    "${source_path}" \
    "${OUT_DIR}/masters/ipad/${slug}.png" \
    328 64 1660 290 1540 144 1708 1540 1022 190 190 244 570

  resize_fill "${OUT_DIR}/masters/phone/${slug}.png" 1320 2868 "${OUT_DIR}/app-store/iphone-6.9/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1080 1920 "${OUT_DIR}/google-play/phone/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1260 2240 "${OUT_DIR}/google-play/tablet-7/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1440 2560 "${OUT_DIR}/google-play/tablet-10/${slug}.png"
  resize_fit "${OUT_DIR}/masters/ipad/${slug}.png" 2064 2752 "${OUT_DIR}/app-store/ipad-13/${slug}.png"
done < <(printf '%s\n' "${slides[@]}")

build_feature_graphic "${OUT_DIR}/google-play/feature-graphic-1024x500.png"
build_promo_poster "${OUT_DIR}/promo/promo-poster-1600x2000.png"

echo "Generated store assets under ${OUT_DIR}"
