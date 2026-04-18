#!/bin/bash
set -e
echo "=== Cleaning LocalFlow ==="
./gradlew clean "$@"
echo "=== Clean complete ==="
