#!/usr/bin/env bash
set -euo pipefail

echo "Running SwiftSoup tests (default backend)"
swift test

echo ""
echo "Running SwiftSoup tests (libxml2 backend)"
SWIFTSOUP_TEST_BACKEND=libxml2 swift test

echo ""
echo "Running SwiftSoup tests (libxml2 backend, swiftSoupParityMode: .libxml2Only - smoke/compat)"
SWIFTSOUP_TEST_BACKEND=libxml2 SWIFTSOUP_TEST_LIBXML2_SKIP_FALLBACKS=1 swift test --filter Libxml2SkipFallback

echo ""
echo "Running SwiftSoup tests (libxml2 backend, swiftSoupParityMode: .libxml2Only - full suite)"
SWIFTSOUP_TEST_BACKEND=libxml2 SWIFTSOUP_TEST_LIBXML2_SKIP_FALLBACKS=1 swift test
