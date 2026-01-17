#!/usr/bin/env bash
set -euo pipefail

echo "Benchmark: SwiftSoupProfile (default backend)"
swift run -c release SwiftSoupProfile "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend)"
swift run -c release SwiftSoupProfile --backend libxml2 "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (default backend, workload defaults)"
swift run -c release SwiftSoupProfile --workload-defaults "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, workload defaults)"
swift run -c release SwiftSoupProfile --backend libxml2 --workload-defaults "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-fast workload)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-fast "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-simple workload)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-simple "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, workload defaults)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-defaults "$@"
