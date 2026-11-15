#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to a Developer ID Application identity in your local Keychain}"
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team}"
STAGE="${1:-$(mktemp -d /tmp/MIDIViewer-release.XXXXXX)}"
mkdir -p "$STAGE"
"$ROOT/Tools/build.sh" "$STAGE/build"
ARCHIVE="$STAGE/MIDIViewer.xcarchive"
mkdir -p "$ARCHIVE/Products/Applications"
ditto --norsrc --noextattr "$STAGE/build/MIDI Viewer.app" "$ARCHIVE/Products/Applications/MIDI Viewer.app"
xattr -cr "$ARCHIVE/Products/Applications/MIDI Viewer.app"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$ARCHIVE/Products/Applications/MIDI Viewer.app"
codesign --verify --deep --strict --verbose=2 "$ARCHIVE/Products/Applications/MIDI Viewer.app"
python3 - "$ARCHIVE" "$SIGN_IDENTITY" "$TEAM_ID" <<'PY'
import sys,plistlib,datetime
from pathlib import Path
archive,identity,team=sys.argv[1:]
info={'ArchiveVersion':2,'CreationDate':datetime.datetime.now(datetime.timezone.utc),'Name':'MIDI Viewer','SchemeName':'MIDI Viewer','ApplicationProperties':{'ApplicationPath':'Applications/MIDI Viewer.app','CFBundleIdentifier':'com.quentinlesceller.MIDIViewer','CFBundleShortVersionString':'1.0','CFBundleVersion':'1','SigningIdentity':identity,'Team':team,'Architectures':['arm64','x86_64']}}
(Path(archive)/'Info.plist').write_bytes(plistlib.dumps(info))
(Path(archive).parent/'ExportOptions.plist').write_bytes(plistlib.dumps({'method':'developer-id','destination':'upload','signingStyle':'manual','signingCertificate':identity,'teamID':team}))
PY
printf 'Archive ready: %s\n' "$ARCHIVE"
printf 'Submit using the existing Xcode account:\n'
printf 'DEVELOPER_DIR=%q xcodebuild -exportArchive -archivePath %q -exportOptionsPlist %q -exportPath %q -allowProvisioningUpdates\n' "$DEVELOPER_DIR" "$ARCHIVE" "$STAGE/ExportOptions.plist" "$STAGE/export"
