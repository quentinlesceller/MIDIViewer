#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/build}"
mkdir -p "$DEST/MIDI Viewer.app/Contents/MacOS" "$DEST/MIDI Viewer.app/Contents/Resources"
SDK="$(xcrun --show-sdk-path)"
for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -target "$ARCH-apple-macos13.0" -sdk "$SDK" \
      -module-cache-path "$DEST/module-cache-$ARCH" "$ROOT"/Sources/*.swift -o "$DEST/MIDIViewer-$ARCH"
done
lipo -create "$DEST/MIDIViewer-arm64" "$DEST/MIDIViewer-x86_64" -output "$DEST/MIDI Viewer.app/Contents/MacOS/MIDI Viewer"
cp "$ROOT/Resources/Info.plist" "$DEST/MIDI Viewer.app/Contents/Info.plist"
cp -R "$ROOT"/Resources/*.lproj "$DEST/MIDI Viewer.app/Contents/Resources/"
cp "$ROOT/Resources/AppIcon.icns" "$DEST/MIDI Viewer.app/Contents/Resources/"
