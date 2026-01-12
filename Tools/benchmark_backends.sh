#!/usr/bin/env bash
set -euo pipefail

echo "Benchmark: SwiftSoupProfile (default backend)"
swift run -c release SwiftSoupProfile "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend)"
swift run -c release SwiftSoupProfile --backend libxml2 "$@"
