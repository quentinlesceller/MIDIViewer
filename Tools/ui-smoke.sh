#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d /tmp/MIDIViewer-ui.XXXXXX)"
APP="$STAGE/MIDI Viewer QA.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGE/cache" \
 "$ROOT/Sources/MIDIFile.swift" "$ROOT/Sources/AudioPlayer.swift" "$ROOT/Sources/PlayerModel.swift" \
 "$ROOT/Sources/ContentView.swift" "$ROOT/Sources/PianoRoll.swift" "$ROOT/Tests/UIHarness.swift" -o "$APP/Contents/MacOS/MIDI Viewer"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.quentinlesceller.MIDIViewer.UIQA' "$APP/Contents/Info.plist"
cp -R "$ROOT"/Resources/*.lproj "$APP/Contents/Resources/"
printf '%s\n' "$APP" > /tmp/MIDIViewer-ui-path
MIDI_QA_FILE="$ROOT/Tests/Fixtures/Type 1 — Tempo & Sustain.midi" "$APP/Contents/MacOS/MIDI Viewer" -AppleLanguages '(fr)'
