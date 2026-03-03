#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-1024x1024-master-png>"
  exit 1
fi

MASTER_ICON="$1"
OUTPUT_DIR="DidAuthApp/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$MASTER_ICON" ]]; then
  echo "Master icon not found: $MASTER_ICON"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

make_icon() {
  local px="$1"
  local name="$2"
  sips -s format png -z "$px" "$px" "$MASTER_ICON" --out "$OUTPUT_DIR/$name" >/dev/null
}

make_icon 40 "Icon-App-20x20@2x.png"
make_icon 60 "Icon-App-20x20@3x.png"
make_icon 58 "Icon-App-29x29@2x.png"
make_icon 87 "Icon-App-29x29@3x.png"
make_icon 80 "Icon-App-40x40@2x.png"
make_icon 120 "Icon-App-40x40@3x.png"
make_icon 120 "Icon-App-60x60@2x.png"
make_icon 180 "Icon-App-60x60@3x.png"

make_icon 20 "Icon-App-20x20@1x.png"
make_icon 40 "Icon-App-20x20@2x~ipad.png"
make_icon 29 "Icon-App-29x29@1x.png"
make_icon 58 "Icon-App-29x29@2x~ipad.png"
make_icon 40 "Icon-App-40x40@1x.png"
make_icon 80 "Icon-App-40x40@2x~ipad.png"
make_icon 76 "Icon-App-76x76@1x.png"
make_icon 152 "Icon-App-76x76@2x.png"
make_icon 167 "Icon-App-83.5x83.5@2x.png"

make_icon 1024 "Icon-App-1024x1024@1x.png"

echo "Generated app icons in $OUTPUT_DIR"
