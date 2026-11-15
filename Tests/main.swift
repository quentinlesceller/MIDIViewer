import Foundation
import AVFoundation
import CryptoKit

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    print("PASS: \(message)")
}
let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
func file(_ name: String) -> URL { fixtures.appendingPathComponent(name) }
let source = file("Type 1 — Tempo & Sustain.midi")
let before = SHA256.hash(data: try Data(contentsOf: source))
let simple = try MIDIFile.load(file("Type 0 — Étude 🎹.mid"))
check(simple.format == 0 && simple.notes.count == 1 && abs(simple.duration - 0.5) < 0.00001, "type 0, Unicode path and timing")
let multi = try MIDIFile.load(source)
check(multi.tracks.count == 4 && multi.notes.count == 52, "type 1 tracks and note count")
check(abs(multi.duration - 14) < 0.00001, "tempo changes: 4 beats at 120, 12 beats at 60 = 14 seconds")
check(Set(multi.events.map { $0.status & 15 }).isSuperset(of: [0,1,9]), "melodic and percussion channels preserved")
check(multi.events.contains { $0.status == 0xc1 && $0.a == 48 }, "instrument program preserved")
check(multi.events.contains { $0.status == 0xb0 && $0.a == 64 && $0.b == 127 }, "sustain controller preserved")
let running = try MIDIFile.load(file("running.mid"))
check(running.notes.count == 2, "running status")
for (name,key) in [("invalid.mid","error.invalid"),("truncated.mid","error.truncated"),("type2.mid","error.format"),("smpte.mid","error.smpte"),("sysex.mid","error.sysex"),("empty.mid","error.empty"),("vlq-invalid.mid","error.invalid")] {
    do { _ = try MIDIFile.load(file(name)); check(false, "reject \(name)") }
    catch let e as MIDIError { check(e.key == key, "clear error for \(name): \(e.key)") }
}
let valid = try Data(contentsOf: file("Type 0 — Étude 🎹.mid"))
for length in 0..<valid.count {
    do { _ = try MIDIFile.parse(valid.prefix(length)); check(false, "reject truncated prefix \(length)") } catch { }
}
check(true, "every truncated prefix rejected without crashing")
// Deterministic mutation corpus catches unsafe lengths/status transitions.
for i in 0..<valid.count {
    var bytes = valid; bytes[i] = 255
    _ = try? MIDIFile.parse(bytes)
}
check(true, "mutated-file corpus processed without crashing")
let audio = try AudioPlayer(offline: true)
let buffer = AVAudioPCMBuffer(pcmFormat: audio.engine.manualRenderingFormat, frameCapacity: 512)!
func render(_ seconds: Double) throws -> Double {
    var energy = 0.0, samples = 0, remaining = Int(seconds * 44100), attempts = 0
    while remaining > 0 {
        attempts += 1
        guard attempts < 100000 else { fatalError("render stalled") }
        let n = AVAudioFrameCount(min(512, remaining))
        let result = try audio.engine.renderOffline(n, to: buffer)
        if result == .success {
            for c in 0..<Int(buffer.format.channelCount) { for i in 0..<Int(buffer.frameLength) {
                let value = Double(buffer.floatChannelData![c][i]); energy += value * value; samples += 1
            } }
            remaining -= Int(buffer.frameLength)
        } else if result == .error { fatalError("offline render failed") }
    }
    return sqrt(energy / Double(max(1,samples)))
}
func event(_ status: UInt8,_ a: UInt8,_ b: UInt8) -> MIDIEvent { MIDIEvent(tick:0,track:0,order:0,status:status,a:a,b:b) }
for (channel, program, pitch) in [(UInt8(0),UInt8(0),UInt8(60)),(1,48,64),(9,0,36)] {
    audio.silence()
    audio.send(event(0xc0|channel,program,0)); audio.send(event(0x90|channel,pitch,100))
    let rms = try render(0.15)
    check(rms > 0.0001, "Apple synth produces audio channel \(channel), program \(program): RMS \(rms)")
}
audio.silence(); audio.send(event(0xc0,0,0)); audio.send(event(0xb0,64,127)); audio.send(event(0x90,60,100))
_ = try render(0.1); audio.send(event(0x80,60,0))
let sustainRMS = try render(0.3)
check(sustainRMS > 0.0001, "sustain remains audible after key release: RMS \(sustainRMS)")
audio.silence(); _ = try render(1.0)
let silentRMS = try render(0.2)
check(silentRMS < 0.00001, "panic leaves no held voices: RMS \(silentRMS)")
audio.load(multi); audio.seek(3); audio.playPause()
let chased = try render(0.1)
check(chased > 0.0001, "seek/restart reconstructs held and sustained notes: RMS \(chased)")
audio.pause(); _ = try render(1.0)
let paused = try render(0.2)
check(paused < 0.00001 && !audio.snapshot().1, "pause is silent")
audio.playPause(); _ = try render(0.1); check(audio.snapshot().1, "resume")
audio.setSpeed(2); let t = audio.snapshot().0; Thread.sleep(forTimeInterval: 0.05)
check(audio.snapshot().0 - t > 0.08, "double-speed transport")
audio.stop(); _ = try render(0.1); check(audio.snapshot().0 == 0 && !audio.snapshot().1, "stop returns to start")
audio.load(simple); _ = try render(0.1); check(audio.snapshot().0 == 0 && !audio.snapshot().1, "successive load resets transport")
audio.seek(0.2); _ = try render(0.1); audio.playPause(); _ = try render(0.1); audio.setMuted([0]); _ = try render(1.0)
let muted = try render(0.2)
print("MUTED RMS: \(muted)")
check(muted < 0.00001, "muted track has no sounding notes")
audio.stop()
let after = SHA256.hash(data: try Data(contentsOf: source))
check(after == before, "original MIDI SHA-256 unchanged")
// Exercise the actual timer -> MIDI synth -> mixer pipeline with a live render tap.
final class Meter: @unchecked Sendable {
    let lock = NSLock()
    var energy = 0.0
    var count = 0
    func collect(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        var e = 0.0
        for c in 0..<Int(buffer.format.channelCount) { for i in 0..<Int(buffer.frameLength) { let v = Double(channels[c][i]); e += v*v } }
        lock.lock(); energy += e; count += Int(buffer.frameLength) * Int(buffer.format.channelCount); lock.unlock()
    }
    func take() -> Double { lock.lock(); defer { lock.unlock() }; let rms = sqrt(energy / Double(max(1,count))); energy = 0; count = 0; return rms }
}
let live = try AudioPlayer()
let meter = Meter()
live.engine.mainMixerNode.installTap(onBus: 0, bufferSize: 512, format: nil) { buffer, _ in meter.collect(buffer) }
live.load(simple); live.playPause(); Thread.sleep(forTimeInterval: 0.25)
let liveRMS = meter.take()
check(liveRMS > 0.0001, "real-time scheduled playback produces mixer audio: RMS \(liveRMS)")
live.pause(); Thread.sleep(forTimeInterval: 1.2); _ = meter.take(); Thread.sleep(forTimeInterval: 0.2)
check(meter.take() < 0.00001, "real-time pause releases all voices")
live.playPause(); Thread.sleep(forTimeInterval: 0.7)
check(!live.snapshot().1 && live.snapshot().0 == simple.duration, "real-time end of song stops transport")
live.load(multi); live.seek(3); live.playPause(); Thread.sleep(forTimeInterval: 0.1); live.seek(8); Thread.sleep(forTimeInterval: 0.1); live.stop()
Thread.sleep(forTimeInterval: 1.2); _ = meter.take(); Thread.sleep(forTimeInterval: 0.2)
check(meter.take() < 0.00001, "real-time seek then stop leaves no held voices")
live.engine.mainMixerNode.removeTap(onBus: 0)
print("SUCCESS: \(checks) checks")
