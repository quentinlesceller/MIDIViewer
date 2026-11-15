import Foundation

struct MIDIError: LocalizedError {
    let key: String
    var errorDescription: String? { NSLocalizedString(key, comment: "MIDI error") }
}
struct MIDIEvent: Sendable {
    let tick: Int
    let track: Int
    let order: Int
    let status: UInt8
    let a: UInt8
    let b: UInt8
    var time: Double = 0
}
struct MIDINote: Identifiable, Sendable {
    let id: Int
    let track: Int
    let pitch: Int
    let velocity: Int
    let start: Double
    let end: Double
}
struct MIDITrack: Identifiable, Sendable {
    let id: Int
    var name: String
    var noteCount: Int = 0
}
struct MIDIFile: Sendable {
    let tracks: [MIDITrack]
    let events: [MIDIEvent]
    let notes: [MIDINote]
    let duration: Double
    let format: Int
    let pitchRange: ClosedRange<Int>
    let noteEndPrefix: [Double]
    func visibleNotes(from start: Double, through end: Double) -> ArraySlice<MIDINote> {
        var lo = 0, hi = notes.count
        while lo < hi { let mid = (lo + hi) / 2; if noteEndPrefix[mid] < start { lo = mid + 1 } else { hi = mid } }
        let first = lo; hi = notes.count
        while lo < hi { let mid = (lo + hi) / 2; if notes[mid].start <= end { lo = mid + 1 } else { hi = mid } }
        return notes[first..<lo]
    }
    static let maxBytes = 32 * 1024 * 1024
    static func load(_ url: URL) throws -> MIDIFile {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maxBytes else { throw MIDIError(key: "error.large") }
        return try parse(Data(contentsOf: url, options: .mappedIfSafe))
    }
    static func parse(_ data: Data) throws -> MIDIFile {
        guard data.count <= maxBytes else { throw MIDIError(key: "error.large") }
        var r = Reader(bytes: Array(data))
        guard try r.ascii(4) == "MThd" else { throw MIDIError(key: "error.invalid") }
        let header = try r.uint(4)
        guard header >= 6, header <= data.count - 8 else { throw MIDIError(key: "error.invalid") }
        let format = try r.uint(2), count = try r.uint(2), division = try r.uint(2)
        guard format <= 1 else { throw MIDIError(key: "error.format") }
        guard division & 0x8000 == 0 else { throw MIDIError(key: "error.smpte") }
        guard division > 0, count > 0, count <= 256, format != 0 || count == 1 else { throw MIDIError(key: "error.invalid") }
        try r.skip(header - 6)
        var tracks: [MIDITrack] = [], events: [MIDIEvent] = []
        var tempos: [(tick: Int, value: Int, order: Int)] = [(0, 500_000, -1)]
        var endTick = 0, order = 0
        for index in 0..<count {
            guard try r.ascii(4) == "MTrk" else { throw MIDIError(key: "error.invalid") }
            let length = try r.uint(4)
            guard length <= r.remaining else { throw MIDIError(key: "error.truncated") }
            var t = Reader(bytes: Array(r.bytes[r.offset..<r.offset+length]))
            try r.skip(length)
            var tick = 0, running: UInt8 = 0, ended = false
            var track = MIDITrack(id: index, name: "")
            while t.remaining > 0 {
                tick += try t.vlq()
                guard tick <= 1_000_000_000 else { throw MIDIError(key: "error.large") }
                var status = try t.byte()
                if status < 0x80 {
                    guard running >= 0x80 else { throw MIDIError(key: "error.invalid") }
                    t.offset -= 1; status = running
                }
                order += 1
                guard order <= 1_000_000 else { throw MIDIError(key: "error.large") }
                if status == 0xff {
                    running = 0
                    let type = try t.byte(), n = try t.vlq()
                    let bytes = try t.read(n)
                    if type == 0x2f {
                        guard n == 0, t.remaining == 0 else { throw MIDIError(key: "error.invalid") }
                        ended = true; break
                    }
                    if type == 0x51 {
                        guard n == 3 else { throw MIDIError(key: "error.invalid") }
                        let value = bytes.reduce(0) { ($0 << 8) | Int($1) }
                        guard value > 0, format == 0 || index == 0 else { throw MIDIError(key: "error.tempo") }
                        tempos.append((tick, value, order))
                    }
                    if type == 3 && track.name.isEmpty {
                        track.name = String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .isoLatin1) ?? ""
                    }
                } else if status == 0xf0 || status == 0xf7 {
                    // Device-specific messages can change tuning/banks and cannot be safely ignored.
                    throw MIDIError(key: "error.sysex")
                } else {
                    guard status < 0xf0 else { throw MIDIError(key: "error.invalid") }
                    running = status
                    let a = try t.byte(), kind = status & 0xf0
                    let b: UInt8 = kind == 0xc0 || kind == 0xd0 ? 0 : try t.byte()
                    guard a < 128, b < 128 else { throw MIDIError(key: "error.invalid") }
                    events.append(MIDIEvent(tick: tick, track: index, order: order, status: status, a: a, b: b))
                    if kind == 0x90 && b > 0 { track.noteCount += 1 }
                }
            }
            guard ended else { throw MIDIError(key: "error.truncated") }
            endTick = max(endTick, tick); tracks.append(track)
        }
        guard r.remaining == 0 else { throw MIDIError(key: "error.invalid") }
        tempos.sort { ($0.tick, $0.order) < ($1.tick, $1.order) }
        var segments: [(tick: Int, time: Double, tempo: Int)] = []
        var previousTick = 0, tempo = 500_000, seconds = 0.0
        for change in tempos {
            seconds += Double(change.tick - previousTick) * Double(tempo) / Double(division) / 1_000_000
            segments.append((change.tick, seconds, change.value))
            previousTick = change.tick; tempo = change.value
        }
        func time(_ tick: Int) -> Double {
            var lo = 0, hi = segments.count
            while lo + 1 < hi { let mid = (lo + hi) / 2; if segments[mid].tick <= tick { lo = mid } else { hi = mid } }
            let s = segments[lo]
            return s.time + Double(tick - s.tick) * Double(s.tempo) / Double(division) / 1_000_000
        }
        let duration = time(endTick)
        guard duration <= 24 * 3600 else { throw MIDIError(key: "error.large") }
        events.sort { ($0.tick, $0.track, $0.order) < ($1.tick, $1.track, $1.order) }
        var active: [Int: [MIDIEvent]] = [:], notes: [MIDINote] = []
        func finish(_ e: MIDIEvent, at end: Double) {
            notes.append(MIDINote(id: notes.count, track: e.track, pitch: Int(e.a), velocity: Int(e.b), start: e.time, end: max(e.time + 0.015, end)))
        }
        for i in events.indices {
            events[i].time = time(events[i].tick)
            let e = events[i], kind = e.status & 0xf0
            // Channels are shared across tracks in Standard MIDI Files.
            let key = Int(e.status & 15) * 128 + Int(e.a)
            if kind == 0x90 && e.b > 0 { active[key, default: []].append(e) }
            else if kind == 0x80 || (kind == 0x90 && e.b == 0) {
                if var stack = active[key], !stack.isEmpty { finish(stack.removeFirst(), at: e.time); active[key] = stack }
            }
        }
        for stack in active.values { for e in stack { finish(e, at: duration) } }
        guard !notes.isEmpty else { throw MIDIError(key: "error.empty") }
        notes.sort { $0.start < $1.start }
        var longestEnd = 0.0
        let prefix = notes.map { note -> Double in longestEnd = max(longestEnd, note.end); return longestEnd }
        let range = max(0, notes.map(\.pitch).min()! - 3)...min(127, notes.map(\.pitch).max()! + 3)
        return MIDIFile(tracks: tracks, events: events, notes: notes, duration: max(duration, 0.1), format: format, pitchRange: range, noteEndPrefix: prefix)
    }
}
private struct Reader {
    let bytes: [UInt8]
    var offset = 0
    var remaining: Int { bytes.count - offset }
    mutating func byte() throws -> UInt8 {
        guard remaining > 0 else { throw MIDIError(key: "error.truncated") }
        defer { offset += 1 }; return bytes[offset]
    }
    mutating func read(_ count: Int) throws -> [UInt8] {
        guard count >= 0, count <= remaining else { throw MIDIError(key: "error.truncated") }
        defer { offset += count }; return Array(bytes[offset..<offset+count])
    }
    mutating func skip(_ n: Int) throws { _ = try read(n) }
    mutating func ascii(_ n: Int) throws -> String { String(bytes: try read(n), encoding: .ascii) ?? "" }
    mutating func uint(_ n: Int) throws -> Int { try read(n).reduce(0) { ($0 << 8) | Int($1) } }
    mutating func vlq() throws -> Int {
        var value = 0
        for _ in 0..<4 { let b = try byte(); value = (value << 7) | Int(b & 127); if b < 128 { return value } }
        throw MIDIError(key: "error.invalid")
    }
}
