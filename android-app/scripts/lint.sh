#!/bin/bash
set -e
echo "=== Running LocalFlow lint ==="
./gradlew lintDebug "$@"
echo "Report: app/build/reports/lint-results-debug.html"
echo "=== Lint complete ==="
