#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="${ROOT_DIR}/docs/readme-assets"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"
if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick not found. Install 'magick' first." >&2
  exit 1
fi

for required in \
  "${ASSET_DIR}/projects-screen.png" \
  "${ASSET_DIR}/community-screen.png" \
  "${ASSET_DIR}/docs-screen.png"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing required screenshot: ${required}" >&2
    exit 1
  fi
done

BOLD_FONT="/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG_FONT="/System/Library/Fonts/Supplemental/Arial.ttf"

CANVAS_W=1600
CANVAS_H=980
CARD_W=330
CARD_H=762
SCREEN_H=720
SCREEN_RADIUS=34
CARD_RADIUS=40

build_card() {
  local name="$1"
  local source="${ASSET_DIR}/${name}-screen.png"
  local cropped="${TMP_DIR}/${name}-cropped.png"
  local bg="${TMP_DIR}/${name}-bg.png"
  local mask="${TMP_DIR}/${name}-mask.png"
  local frame="${TMP_DIR}/${name}-frame.png"
  local shadow="${TMP_DIR}/${name}-shadow.png"

  "${MAGICK_BIN}" "${source}" \
    -resize "${CARD_W}x${SCREEN_H}^" \
    -gravity north \
    -crop "${CARD_W}x${SCREEN_H}+0+0" \
    +repage \
    "${cropped}"

  "${MAGICK_BIN}" -size "${CARD_W}x${CARD_H}" xc:none \
    -fill "#111a33" \
    -draw "roundrectangle 0,0 $((CARD_W - 1)),$((CARD_H - 1)) ${CARD_RADIUS},${CARD_RADIUS}" \
    "${bg}"

  "${MAGICK_BIN}" -size "${CARD_W}x${CARD_H}" xc:black \
    -fill white \
    -draw "roundrectangle 0,0 $((CARD_W - 1)),$((CARD_H - 1)) ${CARD_RADIUS},${CARD_RADIUS}" \
    "${mask}"

  "${MAGICK_BIN}" "${bg}" \
    "${cropped}" -gravity south -geometry +0+0 -composite \
    -fill "rgba(255,255,255,0.045)" \
    -draw "roundrectangle 1,1 $((CARD_W - 2)),$((CARD_H - 2)) ${CARD_RADIUS},${CARD_RADIUS}" \
    -fill "rgba(255,255,255,0.02)" \
    -draw "roundrectangle 1,1 $((CARD_W - 2)),62 ${CARD_RADIUS},${CARD_RADIUS}" \
    "${frame}"

  "${MAGICK_BIN}" "${frame}" "${mask}" -alpha off -compose copy_opacity -composite "${frame}"

  "${MAGICK_BIN}" "${frame}" \
    \( +clone -background "rgba(0,0,0,0.88)" -shadow 80x22+0+18 \) \
    +swap -background none -layers merge +repage \
    "${shadow}"
}

build_card "projects"
build_card "community"
build_card "docs"

"${MAGICK_BIN}" -size "${CANVAS_W}x${CANVAS_H}" xc:"#0b1224" "${TMP_DIR}/base.png"
"${MAGICK_BIN}" "${TMP_DIR}/base.png" \
  \( -size "${CANVAS_W}x${CANVAS_H}" xc:"#131c37" -alpha set -channel A -evaluate set 65% +channel \) -compose over -composite \
  \( -size "${CANVAS_W}x${CANVAS_H}" xc:none -fill "rgba(109,94,252,0.26)" -draw "circle 180,140 430,140" -blur 0x110 \) -compose screen -composite \
  \( -size "${CANVAS_W}x${CANVAS_H}" xc:none -fill "rgba(255,79,151,0.10)" -draw "circle 1380,760 1600,760" -blur 0x120 \) -compose screen -composite \
  \( -size "${CANVAS_W}x${CANVAS_H}" xc:none -fill "rgba(255,255,255,0.035)" -draw "rectangle 0,122 ${CANVAS_W},123" \) -compose over -composite \
  "${TMP_DIR}/hero-bg.png"

"${MAGICK_BIN}" "${TMP_DIR}/hero-bg.png" \
  -fill "rgba(188,186,255,0.18)" -stroke "rgba(255,255,255,0.06)" -strokewidth 1 \
  -draw "roundrectangle 74,56 324,108 24,24" \
  -font "${BOLD_FONT}" -pointsize 24 -fill "#c5c1ff" -annotate +102+90 "d1v.ai mobile" \
  -font "${BOLD_FONT}" -pointsize 66 -fill "#eef2ff" -annotate +72+182 "Build, inspect, and operate" \
  -annotate +72+258 "AI-native projects on mobile." \
  -font "${REG_FONT}" -pointsize 28 -fill "#c0c9e9" -annotate +76+330 "Official Flutter client for projects, community, docs, billing, and operational control." \
  \( "${TMP_DIR}/projects-shadow.png" -background none -rotate -8 \) -geometry +120+410 -composite \
  \( "${TMP_DIR}/community-shadow.png" -background none -rotate 0 \) -geometry +635+322 -composite \
  \( "${TMP_DIR}/docs-shadow.png" -background none -rotate 8 \) -geometry +1148+410 -composite \
  -fill "rgba(15,21,43,0.92)" -stroke "rgba(120,110,255,0.62)" -strokewidth 2 \
  -draw "roundrectangle 132,900 304,946 23,23" \
  -draw "roundrectangle 713,812 915,858 23,23" \
  -draw "roundrectangle 1210,900 1348,946 23,23" \
  -font "${BOLD_FONT}" -pointsize 24 -fill "#eef2ff" -stroke none \
  -annotate +174+931 "Projects" \
  -annotate +755+843 "Community" \
  -annotate +1242+931 "Docs" \
  -background "#0b1224" -alpha remove -alpha off \
  "${ASSET_DIR}/app-overview.png"

echo "Generated ${ASSET_DIR}/app-overview.png"
