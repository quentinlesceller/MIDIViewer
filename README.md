# MIDI Viewer

A small, native, offline MIDI player for **macOS 13 or later**, with a universal **Apple silicon + Intel** binary.

**[Download MIDI Viewer 1.0](https://github.com/quentinlesceller/MIDIViewer/releases/download/v1.0/MIDIViewer-1.0-macOS.zip)** · [Release and checksums](https://github.com/quentinlesceller/MIDIViewer/releases/tag/v1.0)

Unzip, move **MIDI Viewer.app** to **Applications**, and open it. The release is Developer ID signed, uses the hardened runtime, and is notarized by Apple. There is no account, network connection, instrument download, or external synthesizer requirement. macOS supplies the Apple DLS synthesizer and General MIDI instruments; none of Apple's sound-bank resources are redistributed.

## Features

- Open `.mid` and `.midi` through File → Open, ⌘O, drag and drop, or Finder's Open With, including while the player is running.
- Standard MIDI File types 0 and 1, musical tick division, tempo changes, MIDI channels, instruments, velocity, pitch bend, and controllers including sustain.
- Play/pause (Space), stop and rewind (⌘.), time slider, volume, and 50–200% playback speed. ⌘0 restores 100%; ⌘←/⌘→ seek five seconds.
- Track names, show/hide, mute, solo, colored piano roll, moving playhead, and zoom.
- Native SwiftUI/AppKit interface, system light/dark appearance, accessibility labels and keyboard commands.
- English, French, Spanish, German, and Italian, selected by macOS language preferences. English fallback. MIDI text and filenames are preserved.
- Read-only access to original files. All processing stays on the Mac.

## Honest limits

This is a MIDI player and piano-roll viewer, **not a traditional sheet-music converter**. It rejects type 2, SMPTE timing, SysEx (including device-specific bank/tuning messages), malformed/truncated files, and files without playable notes. Type 1 tempo maps must be in the first track. Limits: 32 MB, 256 tracks, one million events, 24 hours.

The piano roll displays key-down durations, not pedal-extended sound tails. Shared MIDI channels retain common instrument/controller settings when a track is muted; mute/solo filter notes. Overlapping same-pitch notes on one shared channel inherit the synthesizer's voice behavior. Sound depends on Apple's system instruments; external-device patches and arbitrary bank mappings are not promised. This is a listening application, not a sample-accurate DAW or MIDI-output utility. The native transport dispatches on a dedicated 2 ms timer; audio-device buffering adds latency.

## Build and test

Install a full Xcode with its macOS SDK and complete its first-run setup. No package manager or third-party dependency is required. The release was built with Xcode 27.2 and the macOS 27.2 SDK, targeting macOS 13.0.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
Tools/build.sh /tmp/MIDIViewer-build
open '/tmp/MIDIViewer-build/MIDI Viewer.app'
Tools/test.sh
```

The build script compiles both architectures and combines them with `lipo`. A locally built app is not a notarized distribution. `Tools/make-icon.swift` is the original editable icon source; `Resources/AppIcon.icns` contains its generated representations.

Tests generate original, CC0 synthetic MIDI fixtures. They validate parsing/error paths, tempos, instruments, channels, percussion, sustain, running status, Unicode paths, truncated prefixes, and source-file preservation. Audio tests measure samples rendered by the actual Apple synthesizer both offline and through the live mixer tap; they also exercise pause/resume, seek, stop, mute, speed, and end of song. Live tests require a working Core Audio output device, but do not record microphone input. Localizations are checked for matching keys and format placeholders.

See [RELEASE.md](RELEASE.md) for the release procedure, test evidence, and remaining validation limits. The GitHub Actions workflow is provided as an **inactive template** in `Tools/ci/macos.yml`: the publishing credential lacks the workflow scope. No CI run is claimed. Copy it to `.github/workflows/macos.yml` with an appropriately authorized account to activate it; audio-device availability on hosted runners may require separating live audio checks.

## Architecture

- `MIDIFile.swift`: bounded Standard MIDI validation, tempo map, note extraction, indexed visualization data.
- `AudioPlayer.swift`: Apple DLS Audio Unit, AVAudioEngine, serialized transport, controller/note chase, voice cleanup.
- `PlayerModel.swift`: async loading, latest-request-wins state, transport bindings and native open panel.
- `MIDIViewerApp.swift`: app lifecycle, native document events, window title and menus.
- `ContentView.swift` and `PianoRoll.swift`: controls, track visibility/mute/solo, native drawing.
- `Resources/*.lproj`: native localization catalogs.

## Français

**[Télécharger MIDI Viewer](https://github.com/quentinlesceller/MIDIViewer/releases/download/v1.0/MIDIViewer-1.0-macOS.zip)**. Décompressez le ZIP, déplacez l’app dans Applications, puis ouvrez-la. Fonctionne entièrement hors ligne, avec les instruments intégrés de macOS. Le fichier original n’est jamais modifié. MIDI standard 0 et 1 à division musicale ; SysEx, SMPTE et conversion en partition non pris en charge. Consultez [INSTALL.txt](INSTALL.txt) pour les commandes simples en français et en anglais.

MIT license. Test MIDI sequences: CC0. No third-party libraries or bundled sound banks.
