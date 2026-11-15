import Foundation
import AVFoundation
import AudioToolbox

/// All transport and MIDI mutations are serialized, independent of the UI run loop.
final class AudioPlayer: @unchecked Sendable {
    let engine = AVAudioEngine()
    let instrument: AVAudioUnitMIDIInstrument
    private let queue = DispatchQueue(label: "MIDIViewer.transport", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var song: MIDIFile?
    private var index = 0
    private var position = 0.0
    private var anchor = ProcessInfo.processInfo.systemUptime
    private var playing = false
    private var speed = 1.0
    private var muted = Set<Int>()
    private var sounding = Set<Int>()
    private var sustainedChannels = Set<UInt8>()
    private var owners: [Int: [Int]] = [:]
    init(offline: Bool = false) throws {
        instrument = AVAudioUnitMIDIInstrument(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: kAudioUnitSubType_DLSSynth,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        engine.attach(instrument)
        engine.connect(instrument, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        if offline {
            try engine.enableManualRenderingMode(.offline, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!, maximumFrameCount: 512)
        }
        try engine.start()
        if !offline {
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(500))
            t.setEventHandler { [weak self] in self?.advance() }
            t.resume(); timer = t
        }
    }
    deinit { timer?.cancel(); engine.stop() }
    func load(_ file: MIDIFile) { queue.sync { silence(); song = file; position = 0; index = 0; playing = false; muted = []; resetChannels() } }
    func snapshot() -> (Double, Bool) { queue.sync { (current(), playing) } }
    func playPause() { queue.sync {
        if playing { position = current(); playing = false; silence() }
        else if let song {
            if position >= song.duration { position = 0 }
            chase(); anchor = ProcessInfo.processInfo.systemUptime; playing = true
        }
    } }
    func stop() { queue.sync { playing = false; position = 0; index = 0; silence() } }
    func pause() { queue.sync { position = current(); playing = false; silence() } }
    func seek(_ seconds: Double) { queue.sync {
        position = min(max(0, seconds), song?.duration ?? 0)
        silence(); if playing { chase() }; anchor = ProcessInfo.processInfo.systemUptime
    } }
    func setSpeed(_ value: Double) { queue.sync { position = current(); anchor = ProcessInfo.processInfo.systemUptime; speed = value } }
    func setVolume(_ value: Float) { queue.sync { engine.mainMixerNode.outputVolume = value } }
    func setMuted(_ tracks: Set<Int>) { queue.sync {
        position = current(); muted = tracks; silence(); if playing { chase() }; anchor = ProcessInfo.processInfo.systemUptime
    } }
    private func current() -> Double {
        min(song?.duration ?? 0, position + (playing ? (ProcessInfo.processInfo.systemUptime - anchor) * speed : 0))
    }
    private func advance() {
        guard playing, let song else { return }
        let now = current()
        while index < song.events.count && song.events[index].time <= now {
            dispatch(song.events[index]); index += 1
        }
        if now >= song.duration { position = song.duration; playing = false; silence() }
    }
    private func dispatch(_ e: MIDIEvent) {
        let kind = e.status & 0xf0, key = Int(e.status & 15) * 128 + Int(e.a)
        if kind == 0x90 && e.b > 0 {
            owners[key, default: []].append(e.track)
            if !muted.contains(e.track) { send(e) }
        } else if kind == 0x80 || (kind == 0x90 && e.b == 0) {
            if var list = owners[key], !list.isEmpty {
                let owner = list.removeFirst(); owners[key] = list
                if !muted.contains(owner) { send(e) }
            }
        } else { send(e) } // Channel-wide controller/program state remains shared, as in SMF.
    }
    func send(_ e: MIDIEvent) {
        let channel = e.status & 15, kind = e.status & 0xf0
        let key = Int(channel) * 128 + Int(e.a)
        if kind == 0x90 && e.b > 0 { sounding.insert(key) }
        if (kind == 0x80 || (kind == 0x90 && e.b == 0)) && !sustainedChannels.contains(channel) { sounding.remove(key) }
        if kind == 0xb0 && e.a == 64 { if e.b >= 64 { sustainedChannels.insert(channel) } else { sustainedChannels.remove(channel) } }
        instrument.sendMIDIEvent(e.status, data1: e.a, data2: e.b)
    }
    func silence() {
        for c: UInt8 in 0..<16 {
            instrument.sendController(64, withValue: 0, onChannel: c)
            for key in sounding where key / 128 == Int(c) { instrument.stopNote(UInt8(key % 128), onChannel: c) }
            instrument.sendController(120, withValue: 0, onChannel: c)
            instrument.sendController(123, withValue: 0, onChannel: c)
        }
        instrument.auAudioUnit.reset()
        sounding.removeAll(); sustainedChannels.removeAll(); owners.removeAll()
    }
    private func resetChannels() {
        for c: UInt8 in 0..<16 {
            instrument.sendController(121, withValue: 0, onChannel: c)
            instrument.sendController(0, withValue: 0, onChannel: c)
            instrument.sendController(32, withValue: 0, onChannel: c)
            instrument.sendProgramChange(0, onChannel: c)
            instrument.sendController(7, withValue: 100, onChannel: c)
            instrument.sendController(10, withValue: 64, onChannel: c)
            instrument.sendController(11, withValue: 127, onChannel: c)
            instrument.sendPitchBend(8192, onChannel: c)
        }
    }
    /// Reconstruct channel state and held/sustained notes, without sounding historical notes.
    private func chase() {
        guard let song else { return }
        resetChannels(); owners.removeAll(); index = 0
        var down: [Int: [MIDIEvent]] = [:], sustained: [Int: [MIDIEvent]] = [:]
        var pedal = Set<Int>()
        var stateEvents: [Int: MIDIEvent] = [:]
        while index < song.events.count && song.events[index].time < position {
            let e = song.events[index], kind = e.status & 0xf0, channel = Int(e.status & 15)
            let key = channel * 128 + Int(e.a)
            if kind == 0x90 && e.b > 0 { down[key, default: []].append(e) }
            else if kind == 0x80 || (kind == 0x90 && e.b == 0) {
                if var list = down[key], !list.isEmpty {
                    let on = list.removeFirst(); down[key] = list
                    if pedal.contains(channel) { sustained[key, default: []].append(on) }
                }
            } else {
                // Only the latest value of each controller/program is needed at a seek.
                let stateKey = Int(e.status) * 256 + (kind == 0xb0 || kind == 0xa0 ? Int(e.a) : 0)
                stateEvents[stateKey] = e
                if kind == 0xb0 {
                    if e.a == 64 {
                        if e.b >= 64 { pedal.insert(channel) }
                        else { pedal.remove(channel); sustained = sustained.filter { $0.key / 128 != channel } }
                    }
                    if e.a == 120 || e.a == 123 {
                        down = down.filter { $0.key / 128 != channel }
                        sustained = sustained.filter { $0.key / 128 != channel }
                    }
                    if e.a == 121 { pedal.remove(channel); sustained = sustained.filter { $0.key / 128 != channel } }
                }
            }
            index += 1
        }
        for e in stateEvents.values.sorted(by: { ($0.time, $0.track, $0.order) < ($1.time, $1.track, $1.order) }) { send(e) }
        for (key, list) in down {
            owners[key] = list.map(\.track)
            for e in list where !muted.contains(e.track) { send(e) }
        }
        for list in sustained.values { for e in list where !muted.contains(e.track) {
            send(e); instrument.sendMIDIEvent(0x80 | (e.status & 15), data1: e.a, data2: 0)
        } }
    }
}
