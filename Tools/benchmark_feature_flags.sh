#!/usr/bin/env bash
set -euo pipefail

ARGS=("$@")

has_iterations=false
for arg in "${ARGS[@]}"; do
    if [[ "$arg" == "--iterations" ]]; then
        has_iterations=true
        break
    fi
done
if [[ "$has_iterations" == "false" ]]; then
    ARGS+=(--iterations 5000000)
fi

echo "Benchmark: SwiftSoupProfile"
swift run -c release SwiftSoupProfile "${ARGS[@]}"
