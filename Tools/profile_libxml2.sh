#!/usr/bin/env bash
set -euo pipefail

echo "Profiling SwiftSoupProfile with libxml2 backend"
swift run -c release -Xswiftc -DPROFILE SwiftSoupProfile --backend libxml2 "$@"
