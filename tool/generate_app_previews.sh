#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/docs/readme-assets/iphone-6.5"
OUT_DIR="${ROOT_DIR}/docs/store-assets-v2/app-store/iphone-6.5/app-previews"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MAGICK_BIN="${MAGICK_BIN:-$(command -v magick)}"
FFMPEG_BIN="${FFMPEG_BIN:-$(command -v ffmpeg || true)}"

if [[ -z "${MAGICK_BIN}" ]]; then
  echo "ImageMagick not found. Install 'magick' first." >&2
  exit 1
fi

if [[ -z "${FFMPEG_BIN}" ]]; then
  echo "ffmpeg not found. Set FFMPEG_BIN=/path/to/ffmpeg or install ffmpeg first." >&2
  exit 1
fi

DISPLAY_FONT="/System/Library/Fonts/Avenir Next.ttc"
BODY_FONT="/System/Library/Fonts/SFNS.ttf"
APP_ICON="${ROOT_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"

WIDTH=886
HEIGHT=1920
FPS=30
SEGMENT_FRAMES=108

for required in \
  "${SRC_DIR}/home-screen.png" \
  "${SRC_DIR}/project-detail-screen.png" \
  "${SRC_DIR}/chat-with-ai-screen.png" \
  "${SRC_DIR}/my-page-screen.png" \
  "${APP_ICON}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing required asset: ${required}" >&2
    exit 1
  fi
done

mkdir -p "${OUT_DIR}"

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

  "${MAGICK_BIN}" -background none -fill "${fill}" -font "${DISPLAY_FONT}" -weight 700 -pointsize "${pointsize}" \
    -size "${width}x${height}" -gravity "${gravity}" caption:"${text}" "${out}"
}

build_base() {
  local out="$1"

  "${MAGICK_BIN}" -size "${WIDTH}x${HEIGHT}" xc:"#08111f" \
    \( -size "${WIDTH}x${HEIGHT}" radial-gradient:"#24436d-#08111f" \) -compose screen -composite \
    \( -size "${WIDTH}x${HEIGHT}" xc:none -fill "rgba(93,111,255,0.18)" -draw "circle 160,260 310,260" -blur 0x38 \) -compose screen -composite \
    \( -size "${WIDTH}x${HEIGHT}" xc:none -fill "rgba(245,95,160,0.10)" -draw "circle 720,1350 900,1350" -blur 0x46 \) -compose screen -composite \
    \( -size "${WIDTH}x${HEIGHT}" xc:none -stroke "rgba(255,255,255,0.055)" -strokewidth 2 -draw "line 0,520 ${WIDTH},520" \) -compose over -composite \
    "${out}"
}

build_brand_pill() {
  local out="$1"
  local width=330
  local height=56
  local inset=8
  local icon_size=40
  local text_x=62

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(255,255,255,0.075)" -stroke "rgba(255,255,255,0.14)" -strokewidth 1 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) 28,28" \
    "${TMP_DIR}/pill-base.png"

  "${MAGICK_BIN}" "${APP_ICON}" -resize "${icon_size}x${icon_size}" "${TMP_DIR}/pill-icon.png"
  render_text $((width - text_x - inset)) "${height}" 24 "#dbe3fb" west "d1v.ai mobile" "${TMP_DIR}/pill-text.png"

  "${MAGICK_BIN}" "${TMP_DIR}/pill-base.png" \
    "${TMP_DIR}/pill-icon.png" -gravity west -geometry "+${inset}+0" -composite \
    "${TMP_DIR}/pill-text.png" -gravity west -geometry "+${text_x}+0" -composite \
    "${out}"
}

build_phone_frame() {
  local source="$1"
  local width="$2"
  local height="$3"
  local out="$4"
  local inset=$((width / 24))
  local radius=$((width / 12))
  local inner_w=$((width - inset * 2))
  local inner_h=$((height - inset * 2))

  if (( inset < 10 )); then
    inset=10
  fi

  "${MAGICK_BIN}" "${source}" \
    -resize "${inner_w}x${inner_h}^" \
    -gravity north \
    -crop "${inner_w}x${inner_h}+0+0" +repage \
    "${TMP_DIR}/phone-source.png"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "#111a31" -stroke "rgba(255,255,255,0.12)" -strokewidth 2 \
    -draw "roundrectangle 1,1 $((width - 2)),$((height - 2)) ${radius},${radius}" \
    "${TMP_DIR}/phone-shell.png"

  "${MAGICK_BIN}" -size "${inner_w}x${inner_h}" xc:none \
    -fill white -draw "roundrectangle 0,0 $((inner_w - 1)),$((inner_h - 1)) $((radius - inset / 2)),$((radius - inset / 2))" \
    "${TMP_DIR}/phone-mask.png"

  "${MAGICK_BIN}" -size "${inner_w}x${inner_h}" xc:none \
    "${TMP_DIR}/phone-source.png" -gravity center -composite \
    "${TMP_DIR}/phone-mask.png" -gravity center -compose copy_opacity -composite \
    "${TMP_DIR}/phone-inner.png"

  "${MAGICK_BIN}" "${TMP_DIR}/phone-shell.png" \
    "${TMP_DIR}/phone-inner.png" -gravity center -composite \
    \( +clone -background "rgba(0,0,0,0.70)" -shadow 42x20+0+22 \) \
    +swap -background none -layers merge +repage \
    "${out}"
}

compose_single_scene() {
  local source="$1"
  local headline="$2"
  local body="$3"
  local out="$4"

  build_base "${TMP_DIR}/base.png"
  build_brand_pill "${TMP_DIR}/pill.png"
  render_display 720 132 54 "#f5f7ff" center "${headline}" "${TMP_DIR}/headline.png"
  render_text 660 84 26 "#c4cdea" center "${body}" "${TMP_DIR}/body.png"
  build_phone_frame "${source}" 612 1324 "${TMP_DIR}/phone.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity north -geometry "+0+62" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+0+152" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+0+318" -composite \
    "${TMP_DIR}/phone.png" -gravity south -geometry "+0-58" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_triptych_scene() {
  local out="$1"

  build_base "${TMP_DIR}/base.png"
  build_brand_pill "${TMP_DIR}/pill.png"
  render_display 760 132 52 "#f5f7ff" center "Context, chat, and delivery in one flow." "${TMP_DIR}/headline.png"
  render_text 650 78 25 "#c4cdea" center "Move from project state into AI execution without switching products." "${TMP_DIR}/body.png"
  build_phone_frame "${SRC_DIR}/home-screen.png" 330 714 "${TMP_DIR}/phone-left.png"
  build_phone_frame "${SRC_DIR}/chat-with-ai-screen.png" 430 930 "${TMP_DIR}/phone-center.png"
  build_phone_frame "${SRC_DIR}/project-detail-screen.png" 330 714 "${TMP_DIR}/phone-right.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity north -geometry "+0+62" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+0+152" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+0+316" -composite \
    \( "${TMP_DIR}/phone-left.png" -background none -rotate -5 \) -gravity southwest -geometry "+38+170" -composite \
    \( "${TMP_DIR}/phone-right.png" -background none -rotate 5 \) -gravity southeast -geometry "+38+170" -composite \
    "${TMP_DIR}/phone-center.png" -gravity south -geometry "+0+92" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_single_scene "${SRC_DIR}/home-screen.png" \
  "AI-native work starts on mobile." \
  "Create projects, track activity, and keep the workspace in reach." \
  "${TMP_DIR}/scene-01.png"

compose_single_scene "${SRC_DIR}/project-detail-screen.png" \
  "Project detail without a desktop detour." \
  "Open status, files, previews, and delivery signals from one project view." \
  "${TMP_DIR}/scene-02.png"

compose_single_scene "${SRC_DIR}/chat-with-ai-screen.png" \
  "Chat with AI where the project lives." \
  "Move from context into execution without losing the thread." \
  "${TMP_DIR}/scene-03.png"

compose_single_scene "${SRC_DIR}/my-page-screen.png" \
  "Workspace controls stay close." \
  "Profile, credits, and settings remain part of the mobile workflow." \
  "${TMP_DIR}/scene-04.png"

compose_triptych_scene "${TMP_DIR}/scene-05.png"

cp "${TMP_DIR}/scene-02.png" "${OUT_DIR}/app-preview-01-poster-frame.png"

: > "${TMP_DIR}/segments.txt"
for index in 01 02 03 04 05; do
  "${FFMPEG_BIN}" -y -loop 1 -i "${TMP_DIR}/scene-${index}.png" \
    -frames:v "${SEGMENT_FRAMES}" \
    -vf "zoompan=z='min(zoom+0.00030,1.022)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${SEGMENT_FRAMES}:s=${WIDTH}x${HEIGHT}:fps=${FPS},format=yuv420p" \
    -r "${FPS}" \
    -c:v libx264 -profile:v high -level:v 4.0 -b:v 10M -maxrate 12M -bufsize 20M \
    -an \
    "${TMP_DIR}/segment-${index}.mp4"
  printf "file '%s'\n" "${TMP_DIR}/segment-${index}.mp4" >> "${TMP_DIR}/segments.txt"
done

"${FFMPEG_BIN}" -y \
  -f concat -safe 0 -i "${TMP_DIR}/segments.txt" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
  -c:v copy \
  -c:a aac -b:a 256k \
  -shortest \
  -movflags +faststart \
  "${OUT_DIR}/app-preview-01-iphone-6.5-886x1920.mp4"

echo "Generated App Preview assets under ${OUT_DIR}"
