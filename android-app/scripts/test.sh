#!/bin/bash
set -e
echo "=== Running LocalFlow unit tests ==="
./gradlew testDebugUnitTest "$@"
echo "=== Tests complete ==="
