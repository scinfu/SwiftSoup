#!/usr/bin/env bash
set -euo pipefail

echo "Benchmark: SwiftSoupProfile (default backend, prettyPrint on)"
swift run -c release SwiftSoupProfile --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (default backend, prettyPrint off)"
swift run -c release SwiftSoupProfile --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (default backend, workload defaults, prettyPrint on)"
swift run -c release SwiftSoupProfile --workload-defaults --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (default backend, workload defaults, prettyPrint off)"
swift run -c release SwiftSoupProfile --workload-defaults --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, workload defaults, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --workload-defaults --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, workload defaults, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --workload-defaults --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-fast workload, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-fast --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-fast workload, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-fast --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-simple workload, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-simple --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, libxml2-simple workload, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-libxml2-simple --no-pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, workload defaults, prettyPrint on)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-defaults --pretty-print "$@"

echo ""
echo ""
echo "Benchmark: SwiftSoupProfile (libxml2 backend, swiftSoupParityMode: .libxml2Only, workload defaults, prettyPrint off)"
swift run -c release SwiftSoupProfile --backend libxml2 --skip-fallbacks --workload-defaults --no-pretty-print "$@"
