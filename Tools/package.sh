#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:?Usage: package.sh /path/to/notarized/app /path/to/output}"
DEST="${2:?Specify output directory}"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
STAGE="$(mktemp -d /tmp/MIDIViewer-package.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/payload" "$STAGE/extracted"
ditto --norsrc --noextattr "$APP" "$STAGE/payload/MIDI Viewer.app"
codesign --verify --deep --strict "$STAGE/payload/MIDI Viewer.app"
xcrun stapler validate "$STAGE/payload/MIDI Viewer.app"
spctl --assess --type execute --verbose=2 "$STAGE/payload/MIDI Viewer.app"
cp "$ROOT/INSTALL.txt" "$ROOT/LICENSE" "$STAGE/payload/"
(cd "$STAGE/payload" && COPYFILE_DISABLE=1 /usr/bin/zip -qry "$DEST/MIDIViewer-1.0-macOS.zip" .)
ditto -xk "$DEST/MIDIViewer-1.0-macOS.zip" "$STAGE/extracted"
codesign --verify --deep --strict "$STAGE/extracted/MIDI Viewer.app"
xcrun stapler validate "$STAGE/extracted/MIDI Viewer.app"
spctl --assess --type execute --verbose=2 "$STAGE/extracted/MIDI Viewer.app"
(cd "$DEST" && shasum -a 256 MIDIViewer-1.0-macOS.zip > SHA256SUMS.txt)
printf 'Verified package: %s/MIDIViewer-1.0-macOS.zip\n' "$DEST"
