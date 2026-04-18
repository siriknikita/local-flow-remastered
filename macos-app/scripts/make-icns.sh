#!/bin/bash
# Convert Icon Kitchen iOS/web output to macOS .icns
# Usage: ./make-icns.sh <icon-kitchen-dir> <output.icns>
#
# Expects Icon Kitchen folder structure with ios/ or web/ subdirectory.
# Uses the largest available PNG (ios-marketing 1024px, or web 512px).

set -e

INPUT_DIR="${1:?Usage: $0 <icon-kitchen-dir> <output.icns>}"
OUTPUT="${2:?Usage: $0 <icon-kitchen-dir> <output.icns>}"

# Find the best source image
SRC=""
if [ -f "$INPUT_DIR/ios/AppIcon~ios-marketing.png" ]; then
    SRC="$INPUT_DIR/ios/AppIcon~ios-marketing.png"
elif [ -f "$INPUT_DIR/web/icon-512.png" ]; then
    SRC="$INPUT_DIR/web/icon-512.png"
elif [ -f "$INPUT_DIR/android/play_store_512.png" ]; then
    SRC="$INPUT_DIR/android/play_store_512.png"
else
    echo "Error: No suitable source image found in $INPUT_DIR"
    exit 1
fi

echo "Source: $SRC"

ICONSET=$(mktemp -d)/App.iconset

mkdir -p "$ICONSET"
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"      > /dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"      > /dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"    > /dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"    > /dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$(dirname "$ICONSET")"

echo "Created: $OUTPUT"
