#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
OUT=$(mktemp -d)
swiftc -swift-version 5 -parse-as-library Sources/Bellows.swift Sources/Keys.swift Tests/LogicTests.swift -o "$OUT/tests"
"$OUT/tests"
