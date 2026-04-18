#!/bin/bash
set -e
echo "=== Installing LocalFlow (debug) ==="
./gradlew installDebug "$@"
echo "=== Install complete ==="
