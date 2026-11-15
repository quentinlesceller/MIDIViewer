# MIDI Viewer 1.0

Release date: 2026-11-15. macOS 13.0+, universal arm64 + x86_64.

## Distribution verification

- Built with Xcode 27.2 using its installed macOS SDK; `DEVELOPER_DIR` was set per process. Global `xcode-select` was not changed.
- Signed with Developer ID Application and hardened runtime. There are no embedded third-party frameworks or executable helpers.
- Submitted through `xcodebuild -exportArchive`, using the existing Apple account in Xcode. Apple accepted the submission; `xcodebuild -exportNotarizedApp` succeeded.
- Stapled ticket validated with `xcrun stapler validate`.
- `codesign --verify --deep --strict` passed. Gatekeeper reported `accepted`, `source=Notarized Developer ID`.
- Packaged outside iCloud into `MIDIViewer-1.0-macOS.zip`. Re-extracted into a fresh `/tmp` directory and repeated all three checks successfully.
- Launched the app from the extracted ZIP, opened the type 1 MIDI, played it, sought to eight seconds, and stopped back at zero using the real interface.
- ZIP inventory: application, English/French installation instructions and MIT license only. No credentials, source build caches, developer account data, or working files are included.
- Signing private keys and account authentication stayed in the local Keychain. No secret was exported or committed. Public signing certificates are naturally part of the app signature.

`SHA256SUMS.txt` accompanies the ZIP on the GitHub release.

## Validation

The recorded automated output is in `Tests/VALIDATION.txt`:

- **33 passing checks** covering types 0/1, tempo changes, channel/program/velocity preservation, percussion, sustain, running status, malformed and truncated data, unsupported types/timing/SysEx, empty files, Unicode filenames, pause/resume, speed, seeking, muting, stop, end of song and original-file SHA-256 preservation.
- All five localization catalogs contain the same 40 nonempty keys and matching format placeholders.
- Actual Apple-synth sample measurements: piano RMS approximately 0.039; strings 0.038; percussion 0.080; sustain after release 0.024. The real-time transport/mixer tap measured RMS approximately 0.036. This verifies audio samples, not merely a “playing” flag.
- Voice cleanup was measured after the short synthesizer release/reverb tail, including pause and seek followed by stop. Muted-track RMS was zero in the fixture.
- Real native UI: French welcome and toolbar, ⌘O, cancel without an error, file selection, file-open events while running, Unicode filename, type 0 and multipiste type 1, pause/play/stop, time slider, 200% speed and reset to 100%, automatic end, hide/mute/solo, invalid-file alert and recovery.
- Production views were additionally inspected in French dark mode at the 720 × 420 minimum content size using `Tools/ui-smoke.sh`. This optional test-only harness does not ship in the release.

Bugs found during validation led to explicit tracked-note release, correct document routing into the shared player window, individual accessibility elements for track controls, stable piano-roll drag coordinates, and bounded visible-note lookup. Tests exercise the audio regressions rather than only checking UI state.

### Validation limits

Tests ran on this Apple silicon Mac with macOS 27.2. The Intel executable compiled successfully, but attempting to execute it returned `Bad CPU type in executable`: Rosetta is not installed/available on this Mac. No physical Intel Mac or macOS 13 machine was available, so runtime testing on those systems is not claimed. Both Mach-O slices target macOS 13.0.

No human listening judgment is claimed; the audio signal was measured offline and on the live mixer. The physical drag gesture was not automated; native file-provider loading is used by the drop handler. The piano-roll view is not traditional notation. See README for supported MIDI limits, SysEx/SMPTE rejection and shared-channel mute semantics.

GitHub Actions has **not run**. The credential permits public repositories/releases but does not have workflow scope, so the workflow remains a template under `Tools/ci`.

## Reproduce a release

1. Run `Tools/test.sh` on a Mac with a working Core Audio output device. Review native UI, including long translations and light/dark modes.
2. Set `SIGN_IDENTITY` to your existing Developer ID Application identity name and `TEAM_ID` to your developer team ID. These are public identifiers, not passwords. Never export a private key or put account credentials in the repository.
3. Run `Tools/archive.sh /tmp/MIDIViewer-release`. The script creates a universal bundle, strips incidental extended attributes before signing, signs with hardened runtime and a timestamp, and creates an Xcode archive.
4. Submit with the command printed by the script:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -exportArchive \
  -archivePath /tmp/MIDIViewer-release/MIDIViewer.xcarchive \
  -exportOptionsPlist /tmp/MIDIViewer-release/ExportOptions.plist \
  -exportPath /tmp/MIDIViewer-release/export -allowProvisioningUpdates
```

5. After Apple finishes processing, export the accepted app. If Xcode says the archive is still processing, wait and retry; do not publish an unaccepted build.

```sh
xcodebuild -exportNotarizedApp \
  -archivePath /tmp/MIDIViewer-release/MIDIViewer.xcarchive \
  -exportPath /tmp/MIDIViewer-release/notarized
Tools/package.sh '/tmp/MIDIViewer-release/notarized/MIDI Viewer.app' /tmp/MIDIViewer-download
```

6. The package script verifies the signature, stapled ticket and Gatekeeper both before and after re-extraction. Launch the extracted app and open a MIDI. Review the ZIP inventory. Publish the tested source tag, ZIP and checksum file together.
7. Download the public ZIP with an unauthenticated client and compare SHA-256 with the validated local archive. Never disable Gatekeeper or instruct users to remove quarantine.
