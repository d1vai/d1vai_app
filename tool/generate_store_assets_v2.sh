#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/docs/readme-assets"
OUT_DIR="${ROOT_DIR}/docs/store-assets-v2"
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
  "${SRC_DIR}/my-page-screen.png" \
  "${SRC_DIR}/project-detail-screen.png" \
  "${SRC_DIR}/chat-with-ai-screen.png" \
  "${APP_ICON}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing required asset: ${required}" >&2
    exit 1
  fi
done

rm -rf \
  "${OUT_DIR}/app-store/iphone-6.9" \
  "${OUT_DIR}/app-store" \
  "${OUT_DIR}/google-play" \
  "${OUT_DIR}/masters" \
  "${OUT_DIR}/promo"

mkdir -p \
  "${OUT_DIR}/app-store/iphone-6.5" \
  "${OUT_DIR}/app-store/ipad-13" \
  "${OUT_DIR}/app-store/apple-watch/ultra-3-422x514" \
  "${OUT_DIR}/app-store/apple-watch/ultra-3-410x502" \
  "${OUT_DIR}/app-store/apple-watch/series-11-416x496" \
  "${OUT_DIR}/app-store/apple-watch/series-9-396x484" \
  "${OUT_DIR}/app-store/apple-watch/series-6-368x448" \
  "${OUT_DIR}/app-store/apple-watch/series-3-312x390" \
  "${OUT_DIR}/google-play/phone" \
  "${OUT_DIR}/google-play/tablet-7" \
  "${OUT_DIR}/google-play/tablet-10" \
  "${OUT_DIR}/google-play" \
  "${OUT_DIR}/promo" \
  "${OUT_DIR}/masters/phone" \
  "${OUT_DIR}/masters/ipad"

slides=(
  "01-home|hero|home-screen.png|AI-native work starts on mobile.|Create projects, track activity, and keep the workspace in reach from the home surface."
  "02-profile|stack|my-page-screen.png|Your workspace, identity, and controls.|Profile, credits, and settings stay close without making the mobile app feel like a thin companion."
  "03-project|focus|project-detail-screen.png|Project detail without the desktop detour.|Open status, files, preview context, and delivery signals from a serious mobile project view."
  "04-chat|triptych|chat-with-ai-screen.png|Chat with AI where the project already lives.|Move from project context into execution without switching products or losing the thread."
)

watch_slides=(
  "01-home|home-screen.png|Home|Projects and activity"
  "02-profile|my-page-screen.png|Profile|Identity and settings"
  "03-project|project-detail-screen.png|Project|Status and delivery"
  "04-chat|chat-with-ai-screen.png|AI Chat|Execution in context"
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

  "${MAGICK_BIN}" -background none -fill "${fill}" -font "${DISPLAY_FONT}" -weight 700 -pointsize "${pointsize}" \
    -size "${width}x${height}" -gravity "${gravity}" caption:"${text}" "${out}"
}

build_base() {
  local width="$1"
  local height="$2"
  local out="$3"
  local cache="${TMP_DIR}/base-${width}x${height}.png"

  if [[ ! -f "${cache}" ]]; then
    "${MAGICK_BIN}" -size "${width}x${height}" xc:"#08111f" \
      \( -size "${width}x${height}" radial-gradient:"#223765-#08111f" \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -fill "rgba(93,111,255,0.18)" -draw "circle $((width / 5)),$((height / 5)) $((width / 5 + width / 8)),$((height / 5))" -blur 0x36 \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -fill "rgba(245,95,160,0.08)" -draw "circle $((width - width / 4)),$((height - height / 3)) $((width - width / 10)),$((height - height / 3))" -blur 0x42 \) -compose screen -composite \
      \( -size "${width}x${height}" xc:none -stroke "rgba(255,255,255,0.045)" -strokewidth 2 -draw "line 0,$((height * 26 / 100)) ${width},$((height * 26 / 100))" \) -compose over -composite \
      "${cache}"
  fi

  cp "${cache}" "${out}"
}

build_brand_pill() {
  local width="$1"
  local height="$2"
  local out="$3"
  local inset=$((height / 7))
  local icon_size=$((height - inset * 2))
  local text_x=$((icon_size + inset * 2 + 10))

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(255,255,255,0.075)" -stroke "rgba(255,255,255,0.11)" -strokewidth 1 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) $((height / 2)),$((height / 2))" \
    "${TMP_DIR}/pill-base.png"

  "${MAGICK_BIN}" "${APP_ICON}" -resize "${icon_size}x${icon_size}" "${TMP_DIR}/pill-icon.png"

  render_text $((width - text_x - inset)) "${height}" $((height / 2 - 5)) "#dbe3fb" west "d1v.ai mobile" "${TMP_DIR}/pill-text.png"

  "${MAGICK_BIN}" "${TMP_DIR}/pill-base.png" \
    "${TMP_DIR}/pill-icon.png" -gravity west -geometry "+${inset}+0" -composite \
    "${TMP_DIR}/pill-text.png" -gravity west -geometry "+${text_x}+0" -composite \
    "${out}"
}

build_chip() {
  local width="$1"
  local height="$2"
  local text="$3"
  local out="$4"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "rgba(18,23,44,0.88)" -stroke "rgba(114,118,255,0.7)" -strokewidth 2 \
    -draw "roundrectangle 0,0 $((width - 1)),$((height - 1)) $((height / 2)),$((height / 2))" \
    "${TMP_DIR}/chip-base.png"

  render_text "${width}" "${height}" $((height / 2 - 3)) "#f4f6ff" center "${text}" "${TMP_DIR}/chip-text.png"

  "${MAGICK_BIN}" "${TMP_DIR}/chip-base.png" "${TMP_DIR}/chip-text.png" -gravity center -composite "${out}"
}

build_card() {
  local source="$1"
  local width="$2"
  local height="$3"
  local radius="$4"
  local out="$5"
  local frame_ratio="${6:-22}"
  local frame_min="${7:-10}"
  local crop_gravity="${8:-center}"
  local frame_inset=$((width < height ? width / frame_ratio : height / frame_ratio))
  if (( frame_inset < frame_min )); then
    frame_inset=frame_min
  fi
  local inner_w=$((width - frame_inset * 2))
  local inner_h=$((height - frame_inset * 2))

  "${MAGICK_BIN}" "${source}" \
    -resize "${inner_w}x${inner_h}^" \
    -gravity "${crop_gravity}" \
    -crop "${inner_w}x${inner_h}+0+0" +repage \
    "${TMP_DIR}/card-source.png"

  "${MAGICK_BIN}" -size "${width}x${height}" xc:none \
    -fill "#1a2440" -stroke "rgba(255,255,255,0.07)" -strokewidth 2 \
    -draw "roundrectangle 1,1 $((width - 2)),$((height - 2)) ${radius},${radius}" \
    "${TMP_DIR}/card-shell.png"

  "${MAGICK_BIN}" -size "${inner_w}x${inner_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((inner_w - 1)),$((inner_h - 1)) $((radius - frame_inset / 2)),$((radius - frame_inset / 2))" \
    "${TMP_DIR}/card-mask.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-shell.png" \
    "${TMP_DIR}/card-source.png" -gravity center -composite \
    "${TMP_DIR}/card-composite.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-composite.png" "${TMP_DIR}/card-mask.png" -gravity center -compose copy_opacity -composite \
    "${TMP_DIR}/card-masked.png"

  "${MAGICK_BIN}" "${TMP_DIR}/card-masked.png" \
    \( +clone -background "rgba(0,0,0,0.72)" -shadow 45x16+0+18 \) \
    +swap -background none -layers merge +repage "${out}"
}

compose_hero() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 12))
  local pill_y=$((height / 18))
  local headline_x=$((width / 12))
  local headline_y=$((height / 8))
  local body_x=$((width / 12))
  local body_y=$((height * 29 / 100))
  local card_y=$((height / 28))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 78 / 100)) $((height / 8)) $((width / 17)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 64 / 100)) $((height / 16)) $((width / 36)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${source}" $((width * 88 / 100)) $((height * 61 / 100)) $((width / 24)) "${TMP_DIR}/card.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    "${TMP_DIR}/card.png" -gravity south -geometry "+0-${card_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_stack() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 14))
  local pill_y=$((height / 16))
  local headline_x=$((width / 14))
  local headline_y=$((height / 7))
  local body_x=$((width / 14))
  local body_y=$((height * 28 / 100))
  local card_a_x=$((width / 3 + width / 40))
  local card_a_y=$((height / 7))
  local card_b_x=$((width / 16))
  local card_b_y=$((height / 16))
  local card_c_x=$((width / 40))
  local card_c_y=$((height / 5))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 40 / 100)) $((height / 6)) $((width / 19)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 38 / 100)) $((height / 12)) $((width / 37)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" $((width * 35 / 100)) $((height * 54 / 100)) $((width / 24)) "${TMP_DIR}/card-a.png" 24 10
  build_card "${source}" $((width * 36 / 100)) $((height * 64 / 100)) $((width / 24)) "${TMP_DIR}/card-b.png" 24 10
  build_card "${SRC_DIR}/project-detail-screen.png" $((width * 30 / 100)) $((height * 49 / 100)) $((width / 26)) "${TMP_DIR}/card-c.png" 24 10

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    \( "${TMP_DIR}/card-a.png" -background none -rotate -8 \) -gravity southeast -geometry "+${card_a_x}+${card_a_y}" -composite \
    "${TMP_DIR}/card-b.png" -gravity southeast -geometry "+${card_b_x}+${card_b_y}" -composite \
    \( "${TMP_DIR}/card-c.png" -background none -rotate 7 \) -gravity southeast -geometry "-${card_c_x}+${card_c_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_focus() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 12))
  local pill_y=$((height / 18))
  local headline_x=$((width / 12))
  local headline_y=$((height / 8))
  local body_x=$((width / 12))
  local body_y=$((height * 27 / 100))
  local card_y=$((height / 30))
  local chip_edge_x=$((width / 7))
  local chip_mid_x=$((width / 18))
  local chip_y=$((height / 22))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 70 / 100)) $((height / 8)) $((width / 18)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 58 / 100)) $((height / 14)) $((width / 37)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${source}" $((width * 94 / 100)) $((height * 66 / 100)) $((width / 24)) "${TMP_DIR}/card.png" 26 10
  build_chip $((width / 6)) $((height / 28)) "Status" "${TMP_DIR}/chip-a.png"
  build_chip $((width / 6)) $((height / 28)) "Files" "${TMP_DIR}/chip-b.png"
  build_chip $((width / 6)) $((height / 28)) "Preview" "${TMP_DIR}/chip-c.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    "${TMP_DIR}/card.png" -gravity south -geometry "+0-${card_y}" -composite \
    "${TMP_DIR}/chip-a.png" -gravity southwest -geometry "+${chip_edge_x}+${chip_y}" -composite \
    "${TMP_DIR}/chip-b.png" -gravity south -geometry "-${chip_mid_x}+${chip_y}" -composite \
    "${TMP_DIR}/chip-c.png" -gravity southeast -geometry "+${chip_edge_x}+${chip_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_triptych() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_y=$((height / 18))
  local headline_y=$((height / 8))
  local body_y=$((height * 26 / 100))
  local side_x=$((width / 4))
  local side_y=$((height / 5))
  local center_y=$((height / 4))
  local side_w=$((width * 32 / 100))
  local side_h=$((side_w * 2868 / 1320))
  local center_w=$((width * 36 / 100))
  local center_h=$((center_w * 2868 / 1320))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 36 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 76 / 100)) $((height / 7)) $((width / 18)) "#f5f7ff" center "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 66 / 100)) $((height / 14)) $((width / 37)) "#c4cdea" center "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-a.png" 24 10
  build_card "${source}" "${center_w}" "${center_h}" $((width / 24)) "${TMP_DIR}/tri-b.png" 24 10
  build_card "${SRC_DIR}/project-detail-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-c.png" 24 10

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity north -geometry "+0+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+0+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+0+${body_y}" -composite \
    \( "${TMP_DIR}/tri-a.png" -background none -rotate -4 \) -gravity south -geometry "-${side_x}-${side_y}" -composite \
    "${TMP_DIR}/tri-b.png" -gravity south -geometry "+0-${center_y}" -composite \
    \( "${TMP_DIR}/tri-c.png" -background none -rotate 4 \) -gravity south -geometry "+${side_x}-${side_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_master() {
  local width="$1"
  local height="$2"
  local layout="$3"
  local source="$4"
  local headline="$5"
  local body="$6"
  local out="$7"

  case "${layout}" in
    hero) compose_hero "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    stack) compose_stack "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    focus) compose_focus "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    triptych) compose_triptych "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    *) echo "Unknown layout: ${layout}" >&2; exit 1 ;;
  esac
}

compose_phone_stack() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 14))
  local pill_y=$((height / 16))
  local headline_x=$((width / 14))
  local headline_y=$((height / 7))
  local body_x=$((width / 14))
  local body_y=$((height * 28 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 40 / 100)) $((height / 6)) $((width / 19)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 36 / 100)) $((height / 12)) $((width / 37)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" $((width * 30 / 100)) $((height * 33 / 100)) $((width / 24)) "${TMP_DIR}/card-a.png" 34 8 north
  build_card "${source}" $((width * 42 / 100)) $((height * 46 / 100)) $((width / 24)) "${TMP_DIR}/card-b.png" 34 8 north
  build_card "${SRC_DIR}/project-detail-screen.png" $((width * 26 / 100)) $((height * 29 / 100)) $((width / 26)) "${TMP_DIR}/card-c.png" 34 8 north

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    \( "${TMP_DIR}/card-a.png" -background none -rotate -8 \) -gravity southeast -geometry "+$((width / 3))+$((height / 10))" -composite \
    "${TMP_DIR}/card-b.png" -gravity southeast -geometry "+$((width / 18))+$((height / 22))" -composite \
    \( "${TMP_DIR}/card-c.png" -background none -rotate 7 \) -gravity southeast -geometry "-$((width / 22))+$((height / 9))" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_phone_focus() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 12))
  local pill_y=$((height / 18))
  local headline_x=$((width / 12))
  local headline_y=$((height / 8))
  local body_x=$((width / 12))
  local body_y=$((height * 25 / 100))
  local card_y=$((height / 20))
  local chip_edge_x=$((width / 7))
  local chip_mid_x=$((width / 18))
  local chip_y=$((height / 28))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 70 / 100)) $((height / 8)) $((width / 18)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 58 / 100)) $((height / 13)) $((width / 37)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${source}" $((width * 96 / 100)) $((height * 70 / 100)) $((width / 24)) "${TMP_DIR}/card.png" 34 8 north
  build_chip $((width / 6)) $((height / 28)) "Status" "${TMP_DIR}/chip-a.png"
  build_chip $((width / 6)) $((height / 28)) "Files" "${TMP_DIR}/chip-b.png"
  build_chip $((width / 6)) $((height / 28)) "Preview" "${TMP_DIR}/chip-c.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    "${TMP_DIR}/card.png" -gravity south -geometry "+0-${card_y}" -composite \
    "${TMP_DIR}/chip-a.png" -gravity southwest -geometry "+${chip_edge_x}+${chip_y}" -composite \
    "${TMP_DIR}/chip-b.png" -gravity south -geometry "-${chip_mid_x}+${chip_y}" -composite \
    "${TMP_DIR}/chip-c.png" -gravity southeast -geometry "+${chip_edge_x}+${chip_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_phone_triptych() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_y=$((height / 18))
  local headline_y=$((height / 8))
  local body_y=$((height * 24 / 100))
  local side_x=$((width / 4))
  local side_y=$((height / 10))
  local center_y=$((height / 10))
  local side_w=$((width * 28 / 100))
  local side_h=$((height * 34 / 100))
  local center_w=$((width * 38 / 100))
  local center_h=$((height * 42 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 36 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 76 / 100)) $((height / 7)) $((width / 18)) "#f5f7ff" center "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 66 / 100)) $((height / 14)) $((width / 37)) "#c4cdea" center "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-a.png" 34 8 north
  build_card "${source}" "${center_w}" "${center_h}" $((width / 24)) "${TMP_DIR}/tri-b.png" 34 8 north
  build_card "${SRC_DIR}/project-detail-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-c.png" 34 8 north

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity north -geometry "+0+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+0+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+0+${body_y}" -composite \
    \( "${TMP_DIR}/tri-a.png" -background none -rotate -4 \) -gravity south -geometry "-${side_x}-${side_y}" -composite \
    "${TMP_DIR}/tri-b.png" -gravity south -geometry "+0-${center_y}" -composite \
    \( "${TMP_DIR}/tri-c.png" -background none -rotate 4 \) -gravity south -geometry "+${side_x}-${side_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_phone() {
  local width="$1"
  local height="$2"
  local layout="$3"
  local source="$4"
  local headline="$5"
  local body="$6"
  local out="$7"

  case "${layout}" in
    hero) compose_hero "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    stack) compose_phone_stack "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    focus) compose_phone_focus "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    triptych) compose_phone_triptych "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    *) echo "Unknown phone layout: ${layout}" >&2; exit 1 ;;
  esac
}

compose_iphone65_stack() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 14))
  local pill_y=$((height / 18))
  local headline_x=$((width / 14))
  local headline_y=$((height / 8))
  local body_x=$((width / 14))
  local body_y=$((height * 31 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 40 / 100)) $((height / 5)) $((width / 18)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 32 / 100)) $((height / 10)) $((width / 39)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" $((width * 30 / 100)) $((height * 38 / 100)) $((width / 24)) "${TMP_DIR}/card-a.png" 34 8 north
  build_card "${source}" $((width * 42 / 100)) $((height * 44 / 100)) $((width / 24)) "${TMP_DIR}/card-b.png" 34 8 north
  build_card "${SRC_DIR}/project-detail-screen.png" $((width * 26 / 100)) $((height * 34 / 100)) $((width / 26)) "${TMP_DIR}/card-c.png" 34 8 north

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    \( "${TMP_DIR}/card-a.png" -background none -rotate -6 \) -gravity southeast -geometry "+$((width / 3))+$((height / 9))" -composite \
    "${TMP_DIR}/card-b.png" -gravity southeast -geometry "+$((width / 20))+$((height / 22))" -composite \
    \( "${TMP_DIR}/card-c.png" -background none -rotate 5 \) -gravity southeast -geometry "-$((width / 24))+$((height / 8))" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_iphone65_focus() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_x=$((width / 12))
  local pill_y=$((height / 18))
  local headline_x=$((width / 12))
  local headline_y=$((height / 8))
  local body_x=$((width / 12))
  local body_y=$((height * 27 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 44 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 70 / 100)) $((height / 8)) $((width / 18)) "#f5f7ff" west "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 60 / 100)) $((height / 12)) $((width / 38)) "#c4cdea" west "${body}" "${TMP_DIR}/body.png"
  build_card "${source}" $((width * 96 / 100)) $((height * 52 / 100)) $((width / 24)) "${TMP_DIR}/card.png" 34 8 north
  build_chip $((width / 6)) $((height / 30)) "Status" "${TMP_DIR}/chip-a.png"
  build_chip $((width / 6)) $((height / 30)) "Files" "${TMP_DIR}/chip-b.png"
  build_chip $((width / 6)) $((height / 30)) "Preview" "${TMP_DIR}/chip-c.png"

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity northwest -geometry "+${pill_x}+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity northwest -geometry "+${headline_x}+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity northwest -geometry "+${body_x}+${body_y}" -composite \
    "${TMP_DIR}/card.png" -gravity south -geometry "+0-$((height / 9))" -composite \
    "${TMP_DIR}/chip-a.png" -gravity south -geometry "-$((width / 4))-$((height / 22))" -composite \
    "${TMP_DIR}/chip-b.png" -gravity south -geometry "+0-$((height / 22))" -composite \
    "${TMP_DIR}/chip-c.png" -gravity south -geometry "+$((width / 4))-$((height / 22))" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_iphone65_triptych() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_y=$((height / 18))
  local headline_y=$((height / 8))
  local body_y=$((height * 24 / 100))
  local side_w=$((width * 29 / 100))
  local side_h=$((height * 31 / 100))
  local center_w=$((width * 40 / 100))
  local center_h=$((height * 36 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/base.png"
  build_brand_pill $((width * 36 / 100)) $((height / 24)) "${TMP_DIR}/pill.png"
  render_display $((width * 76 / 100)) $((height / 7)) $((width / 18)) "#f5f7ff" center "${headline}" "${TMP_DIR}/headline.png"
  render_text $((width * 66 / 100)) $((height / 14)) $((width / 38)) "#c4cdea" center "${body}" "${TMP_DIR}/body.png"
  build_card "${SRC_DIR}/home-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-a.png" 34 8 north
  build_card "${source}" "${center_w}" "${center_h}" $((width / 24)) "${TMP_DIR}/tri-b.png" 34 8 north
  build_card "${SRC_DIR}/project-detail-screen.png" "${side_w}" "${side_h}" $((width / 24)) "${TMP_DIR}/tri-c.png" 34 8 north

  "${MAGICK_BIN}" "${TMP_DIR}/base.png" \
    "${TMP_DIR}/pill.png" -gravity north -geometry "+0+${pill_y}" -composite \
    "${TMP_DIR}/headline.png" -gravity north -geometry "+0+${headline_y}" -composite \
    "${TMP_DIR}/body.png" -gravity north -geometry "+0+${body_y}" -composite \
    \( "${TMP_DIR}/tri-a.png" -background none -rotate -5 \) -gravity south -geometry "-$((width / 4))-$((height / 11))" -composite \
    "${TMP_DIR}/tri-b.png" -gravity south -geometry "+0-$((height / 10))" -composite \
    \( "${TMP_DIR}/tri-c.png" -background none -rotate 5 \) -gravity south -geometry "+$((width / 4))-$((height / 11))" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

compose_iphone65() {
  local layout="$1"
  local width="$2"
  local height="$3"
  local source="$4"
  local headline="$5"
  local body="$6"
  local out="$7"

  case "${layout}" in
    hero) compose_hero "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    stack) compose_iphone65_stack "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    focus) compose_iphone65_focus "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    triptych) compose_iphone65_triptych "${width}" "${height}" "${source}" "${headline}" "${body}" "${out}" ;;
    *) echo "Unknown iPhone 6.5 layout: ${layout}" >&2; exit 1 ;;
  esac
}

compose_watch_poster() {
  local width="$1"
  local height="$2"
  local source="$3"
  local headline="$4"
  local body="$5"
  local out="$6"
  local pill_w=$((width * 56 / 100))
  local pill_h=$((height / 11))
  local pill_y=$((height / 20))
  local headline_y=$((height / 6))
  local body_y=$((height * 26 / 100))
  local card_w=$((width * 82 / 100))
  local card_h=$((height * 46 / 100))
  local card_y=$((height * 6 / 100))

  build_base "${width}" "${height}" "${TMP_DIR}/watch-base.png"
  build_brand_pill "${pill_w}" "${pill_h}" "${TMP_DIR}/watch-pill.png"
  render_display $((width * 76 / 100)) $((height / 8)) $((width / 11)) "#f5f7ff" center "${headline}" "${TMP_DIR}/watch-headline.png"
  render_text $((width * 72 / 100)) $((height / 10)) $((width / 23)) "#c4cdea" center "${body}" "${TMP_DIR}/watch-body.png"
  build_card "${source}" "${card_w}" "${card_h}" $((width / 12)) "${TMP_DIR}/watch-card.png" 18 8

  "${MAGICK_BIN}" "${TMP_DIR}/watch-base.png" \
    "${TMP_DIR}/watch-pill.png" -gravity north -geometry "+0+${pill_y}" -composite \
    "${TMP_DIR}/watch-headline.png" -gravity north -geometry "+0+${headline_y}" -composite \
    "${TMP_DIR}/watch-body.png" -gravity north -geometry "+0+${body_y}" -composite \
    "${TMP_DIR}/watch-card.png" -gravity south -geometry "+0-${card_y}" -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

resize_fill() {
  local source="$1"
  local width="$2"
  local height="$3"
  local out="$4"
  "${MAGICK_BIN}" "${source}" -resize "${width}x${height}^" -gravity center -crop "${width}x${height}+0+0" +repage "${out}"
}

resize_fit() {
  local source="$1"
  local width="$2"
  local height="$3"
  local out="$4"
  "${MAGICK_BIN}" "${source}" -resize "${width}x${height}!" "${out}"
}

build_feature_graphic() {
  local out="$1"

  build_base 1024 500 "${TMP_DIR}/feature-base.png"
  build_brand_pill 330 44 "${TMP_DIR}/feature-pill.png"
  render_display 430 178 32 "#f5f7ff" west "Projects, chat, and account controls in one mobile workspace." "${TMP_DIR}/feature-headline.png"
  render_text 390 72 18 "#c4cdea" west "A more serious control plane for AI-native builders working away from desktop." "${TMP_DIR}/feature-body.png"
  build_card "${SRC_DIR}/home-screen.png" 164 320 24 "${TMP_DIR}/fg-a.png" 24 10
  build_card "${SRC_DIR}/project-detail-screen.png" 164 344 24 "${TMP_DIR}/fg-b.png" 24 10
  build_card "${SRC_DIR}/chat-with-ai-screen.png" 164 320 24 "${TMP_DIR}/fg-c.png" 24 10

  "${MAGICK_BIN}" "${TMP_DIR}/feature-base.png" \
    "${TMP_DIR}/feature-pill.png" -gravity northwest -geometry +60+46 -composite \
    "${TMP_DIR}/feature-headline.png" -gravity northwest -geometry +60+108 -composite \
    "${TMP_DIR}/feature-body.png" -gravity northwest -geometry +62+288 -composite \
    \( "${TMP_DIR}/fg-a.png" -background none -rotate -4 \) -gravity northeast -geometry +252+120 -composite \
    "${TMP_DIR}/fg-b.png" -gravity northeast -geometry +124+72 -composite \
    \( "${TMP_DIR}/fg-c.png" -background none -rotate 4 \) -gravity northeast -geometry +8+120 -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

build_promo_poster() {
  local out="$1"

  build_base 1600 2000 "${TMP_DIR}/poster-base.png"
  build_brand_pill 440 58 "${TMP_DIR}/poster-pill.png"
  render_display 1220 270 78 "#f5f7ff" west "AI-native work should stay intact when you leave your desk." "${TMP_DIR}/poster-headline.png"
  render_text 1120 120 32 "#c4cdea" west "d1v.ai keeps home, project detail, chat with AI, and account controls connected inside one mobile workflow." "${TMP_DIR}/poster-body.png"
  build_card "${SRC_DIR}/home-screen.png" 430 920 40 "${TMP_DIR}/poster-a.png" 24 10
  build_card "${SRC_DIR}/chat-with-ai-screen.png" 430 1040 40 "${TMP_DIR}/poster-b.png" 24 10
  build_card "${SRC_DIR}/my-page-screen.png" 430 920 40 "${TMP_DIR}/poster-c.png" 24 10

  "${MAGICK_BIN}" "${TMP_DIR}/poster-base.png" \
    "${TMP_DIR}/poster-pill.png" -gravity northwest -geometry +118+118 -composite \
    "${TMP_DIR}/poster-headline.png" -gravity northwest -geometry +118+216 -composite \
    "${TMP_DIR}/poster-body.png" -gravity northwest -geometry +122+540 -composite \
    \( "${TMP_DIR}/poster-a.png" -background none -rotate -3 \) -gravity south -geometry -430-74 -composite \
    "${TMP_DIR}/poster-b.png" -gravity south -geometry +0-28 -composite \
    \( "${TMP_DIR}/poster-c.png" -background none -rotate 3 \) -gravity south -geometry +430-74 -composite \
    -background "#08111f" -alpha remove -alpha off \
    "${out}"
}

while IFS='|' read -r slug layout source_file headline body; do
  source_path="${SRC_DIR}/${source_file}"

  compose_phone 1440 2560 "${layout}" "${source_path}" "${headline}" "${body}" "${OUT_DIR}/masters/phone/${slug}.png"
  compose_master 2064 2752 "${layout}" "${source_path}" "${headline}" "${body}" "${OUT_DIR}/masters/ipad/${slug}.png"

  compose_iphone65 "${layout}" 1284 2778 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/iphone-6.5/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1080 1920 "${OUT_DIR}/google-play/phone/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1260 2240 "${OUT_DIR}/google-play/tablet-7/${slug}.png"
  resize_fit "${OUT_DIR}/masters/phone/${slug}.png" 1440 2560 "${OUT_DIR}/google-play/tablet-10/${slug}.png"
  resize_fit "${OUT_DIR}/masters/ipad/${slug}.png" 2064 2752 "${OUT_DIR}/app-store/ipad-13/${slug}.png"
done < <(printf '%s\n' "${slides[@]}")

while IFS='|' read -r slug source_file headline body; do
  source_path="${SRC_DIR}/${source_file}"
  compose_watch_poster 422 514 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/ultra-3-422x514/${slug}.png"
  compose_watch_poster 410 502 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/ultra-3-410x502/${slug}.png"
  compose_watch_poster 416 496 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/series-11-416x496/${slug}.png"
  compose_watch_poster 396 484 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/series-9-396x484/${slug}.png"
  compose_watch_poster 368 448 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/series-6-368x448/${slug}.png"
  compose_watch_poster 312 390 "${source_path}" "${headline}" "${body}" "${OUT_DIR}/app-store/apple-watch/series-3-312x390/${slug}.png"
done < <(printf '%s\n' "${watch_slides[@]}")

build_feature_graphic "${OUT_DIR}/google-play/feature-graphic-1024x500.png"
build_promo_poster "${OUT_DIR}/promo/promo-poster-1600x2000.png"

echo "Generated v2 store assets under ${OUT_DIR}"
