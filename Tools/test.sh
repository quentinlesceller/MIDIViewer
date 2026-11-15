#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/MIDIViewer-tests.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
python3 "$ROOT/Tests/make-fixtures.py"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos13.0" -module-cache-path "$TEMP/cache" "$ROOT/Sources/MIDIFile.swift" "$ROOT/Sources/AudioPlayer.swift" "$ROOT/Tests/main.swift" -o "$TEMP/tests"
"$TEMP/tests" "$ROOT/Tests/Fixtures"
python3 "$ROOT/Tests/check-localizations.py"
