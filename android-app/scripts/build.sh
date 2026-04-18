#!/bin/bash
set -e
echo "=== Building LocalFlow (debug) ==="
./gradlew assembleDebug "$@"

APK_PATH="$(pwd)/app/build/outputs/apk/debug/app-debug.apk"
osascript -e "set the clipboard to POSIX file \"$APK_PATH\""
echo "=== Build successful — APK copied to clipboard ==="
