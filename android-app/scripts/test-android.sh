#!/bin/bash
set -e
echo "=== Running LocalFlow instrumented tests ==="
./gradlew connectedDebugAndroidTest "$@"
echo "=== Tests complete ==="
