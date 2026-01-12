#!/usr/bin/env bash
set -euo pipefail

echo "Running SwiftSoup tests (default backend)"
swift test

echo ""
echo "Running SwiftSoup tests (libxml2 backend)"
SWIFTSOUP_TEST_BACKEND=libxml2 swift test
