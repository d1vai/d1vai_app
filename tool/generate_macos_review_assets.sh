#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/docs/readme-assets"
OUT_ROOT="${ROOT_DIR}/docs/app-store-review/macos/local-assets/screenshots"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"
if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick not found. Install 'magick' first." >&2
  exit 1
fi

DISPLAY_FONT="/System/Library/Fonts/Avenir Next.ttc"
BODY_FONT="/System/Library/Fonts/SFNS.ttf"
APP_ICON="${ROOT_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"

for required in \
  "${SRC_DIR}/home-screen.png" \
  "${SRC_DIR}/project-detail-screen.png" \
  "${SRC_DIR}/chat-with-ai-screen.png" \
  "${SRC_DIR}/community-screen.png" \
  "${SRC_DIR}/docs-screen.png" \
  "${SRC_DIR}/my-page-screen.png" \
  "${APP_ICON}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing required asset: ${required}" >&2
    exit 1
  fi
done

mkdir -p \
  "${OUT_ROOT}/1440x900" \
  "${OUT_ROOT}/2880x1800"

slides=(
  "01-dashboard|home-screen.png|AI projects stay within reach on Mac.|Open active work, scan activity, and move back into execution without losing context."
  "02-project-overview|project-detail-screen.png|Project health, files, and delivery signals in one view.|Use the desktop layout to inspect the project surface instead of bouncing between tools."
  "03-project-chat|chat-with-ai-screen.png|Continue AI execution inside the project thread.|Keep prompts, project context, and generated output connected to the same workspace."
  "04-community|community-screen.png|See what the community is building.|Browse published work and creator activity without leaving the app."
  "05-docs|docs-screen.png|Documentation is available where the work happens.|Search guides, workflows, and implementation references from the same desktop client."
  "06-profile|my-page-screen.png|Account controls, credits, and settings stay close.|Identity, workspace settings, and account state remain easy to verify during review."
)

render_text() {
  local width="$1"
  local height="$2"
  local pointsize="$3"
  local fill="$4"
  local gravity="$5"
  local text="$6"
  local out="$7"

  "${MAGICK_BIN}" -background none -fill "${fill}" -font "${BODY_FONT}" -pointsize "${pointsize}" \
    -size "${width}x${height}" -gravity "${gravity}" caption:"${text}" "${out}"
}

render_display() {
  local width="$1"
  local height="$2"
  local pointsize="$3"
  local fill="$4"
  local gravity="$5"
  local text="$6"
  local out="$7"

  local safe_pad=$((pointsize / 5))
  if (( safe_pad < 10 )); then
    safe_pad=10
  fi

  "${MAGICK_BIN}" -background none -fill "${fill}" -font "${DISPLAY_FONT}" -weight 700 \
    -interline-spacing $((pointsize / 10)) -pointsize "${pointsize}" \
    -size "${width}x${height}" -gravity "${gravity}" caption:"${text}" \
    -bordercolor none -border "0x${safe_pad}" "${out}"
}

build_base() {
  local width="$1"
  local height="$2"
  local out="$3"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:"#0a1220" \
    \( -size "${width}x${height}" radial-gradient:"#244373-#0a1220" \) -compose screen -composite \
    \( -size "${width}x${height}" xc:none -fill "rgba(72,126,255,0.18)" -draw "circle $((width / 6)),$((height / 5)) $((width / 6 + width / 10)),$((height / 5))" -blur 0x44 \) -compose screen -composite \
    \( -size "${width}x${height}" xc:none -fill "rgba(12,196,170,0.10)" -draw "circle $((width - width / 5)),$((height - height / 4)) $((width - width / 12)),$((height - height / 4))" -blur 0x52 \) -compose screen -composite \
    "${out}"
}

build_brand_pill() {
  local width="$1"
  local height="$2"
  local out="$3"
  local inset=$((height / 10))
  local icon_size=$((height * 76 / 100))
  local icon_radius=$((icon_size / 5))
  local text_x=$((icon_size + inset * 2 + 14))

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(255,255,255,0.08)" -stroke "rgba(255,255,255,0.12)" -strokewidth 1 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) $((height / 2)),$((height / 2))" \
    "${TMP_DIR}/pill-base.png"

  "${MAGICK_BIN}" "${APP_ICON}" -resize "${icon_size}x${icon_size}^" -gravity center -crop "${icon_size}x${icon_size}+0+0" +repage "${TMP_DIR}/pill-icon-source.png"
  "${MAGICK_BIN}" -size "${icon_size}x${icon_size}" xc:none \
    -fill white -draw "roundrectangle 0,0 $((icon_size - 1)),$((icon_size - 1)) ${icon_radius},${icon_radius}" \
    "${TMP_DIR}/pill-icon-mask.png"
  "${MAGICK_BIN}" "${TMP_DIR}/pill-icon-source.png" "${TMP_DIR}/pill-icon-mask.png" -compose copy_opacity -composite "${TMP_DIR}/pill-icon.png"
  render_text $((width - text_x - inset)) "${height}" $((height / 2 - 4)) "#dce7ff" west "d1v for macOS" "${TMP_DIR}/pill-text.png"

  "${MAGICK_BIN}" "${TMP_DIR}/pill-base.png" \
    "${TMP_DIR}/pill-icon.png" -gravity west -geometry "+${inset}+0" -composite \
    "${TMP_DIR}/pill-text.png" -gravity west -geometry "+${text_x}+0" -composite \
    "${out}"
}

build_window_shell() {
  local width="$1"
  local height="$2"
  local radius="$3"
  local out="$4"
  local titlebar_h=$((height / 13))
  local dot_y=$((titlebar_h / 2))
  local dot_r=$((titlebar_h / 6))
  local dot_gap=$((dot_r * 3))
  local start_x=$((dot_gap * 2))

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "#101b2d" -stroke "rgba(255,255,255,0.10)" -strokewidth 2 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) ${radius},${radius}" \
    -fill "#152238" -stroke none \
    -draw "roundrectangle 1,1 $((width - 2)),$((titlebar_h)) ${radius},${radius}" \
    -fill "#ff605c" -draw "circle ${start_x},${dot_y} $((start_x + dot_r)),${dot_y}" \
    -fill "#ffbd44" -draw "circle $((start_x + dot_gap)),${dot_y} $((start_x + dot_gap + dot_r)),${dot_y}" \
    -fill "#00ca4e" -draw "circle $((start_x + dot_gap * 2)),${dot_y} $((start_x + dot_gap * 2 + dot_r)),${dot_y}" \
    "${out}"
}

compose_slide() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"

  local left_w=$((width * 38 / 100))
  local pill_x=$((width / 18))
  local pill_y=$((height / 14))
  local headline_x=$((width / 18))
  local headline_y=$((height * 24 / 100))
  local body_x=$((width / 18))
  local body_y=$((height * 47 / 100))
  local window_w=$((width * 53 / 100))
  local window_h=$((height * 72 / 100))
  local window_x=$((width / 22))
  local window_y=$((height / 24))
  local inner_pad=$((window_w / 35))
  local titlebar_h=$((window_h / 13))
  local inner_w=$((window_w - inner_pad * 2))
  local inner_h=$((window_h - titlebar_h - inner_pad * 2 + inner_pad / 2))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((left_w * 85 / 100)) $((height / 18)) "${TMP_DIR}/pill.png"
  render_display $((left_w * 90 / 100)) $((height * 28 / 100)) $((width / 34)) "#f6f8ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((left_w * 88 / 100)) $((height / 6)) $((width / 60)) "#c9d4ee" west "${body}" "${TMP_DIR}/body.png"
  build_window_shell "${window_w}" "${window_h}" $((width / 48)) "${TMP_DIR}/window-shell.png"

  "${MAGICK_BIN}" "${source}" \
    -resize "${inner_w}x${inner_h}^" \
    -gravity north \
    -crop "${inner_w}x${inner_h}+0+0" +repage \
    "${TMP_DIR}/window-content.png"

  "${MAGICK_BIN}" "${TMP_DIR}/window-shell.png" \
    "${TMP_DIR}/window-content.png" -gravity south -geometry "+0+${inner_pad}" -composite \
    "${TMP_DIR}/window.png"

  "${MAGICK_BIN}" "${TMP_DIR}/window.png" \
    \( +clone -background "rgba(0,0,0,0.55)" -shadow 55x20+0+22 \) \
    +swap -background none -layers merge +repage "${TMP_DIR}/window-shadow.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    "${TMP_DIR}/window-shadow.png" -gravity east -geometry "+${window_x}+${window_y}" -composite \
    -background "#0a1220" -alpha remove -alpha off \
    "${out}"
}

render_size() {
  local width="$1"
  local height="$2"
  local dir="${OUT_ROOT}/${width}x${height}"
  mkdir -p "${dir}"
  rm -f "${dir}"/*.png

  for slide in "${slides[@]}"; do
    IFS='|' read -r name source headline body <<< "${slide}"
    compose_slide "${width}" "${height}" "${SRC_DIR}/${source}" "${headline}" "${body}" "${dir}/${name}.png"
    echo "Generated ${dir}/${name}.png"
  done
}

render_size 1440 900
render_size 2880 1800

echo "macOS review assets generated under ${OUT_ROOT}"
