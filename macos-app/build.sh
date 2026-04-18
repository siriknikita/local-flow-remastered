#!/bin/bash
set -e

cd "$(dirname "$0")/LocalFlow"

echo "=== Building LocalFlow.app ==="
swift build -c debug

APP_DIR=".build/LocalFlow.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS"

cp .build/arm64-apple-macosx/debug/LocalFlow "$MACOS/LocalFlow"
cp Sources/App/Info.plist "$CONTENTS/Info.plist"

echo "=== Build complete: $APP_DIR ==="
echo "Run with: open $APP_DIR"
