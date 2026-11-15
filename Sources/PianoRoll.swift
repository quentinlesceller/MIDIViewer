import SwiftUI

struct PianoRoll: View {
    let song: MIDIFile
    let position: Double
    let zoom: Double
    let hidden: Set<Int>
    let seek: (Double) -> Void
    @State private var dragOrigin: Double?
    static let colors: [Color] = [.teal, .orange, .purple, .blue, .pink, .green, .indigo]
    var body: some View {
        GeometryReader { geometry in
            let left = 38.0, top = 26.0
            let span = max(2, 20 / zoom)
            let start = max(0, position - span * 0.3)
            let width = max(1, geometry.size.width - left)
            let low = song.pitchRange.lowerBound
            let high = song.pitchRange.upperBound
            let row = (geometry.size.height - top) / Double(high - low + 1)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: .textBackgroundColor)))
                for pitch in low...high {
                    let y = top + Double(high - pitch) * row
                    let black = [1, 3, 6, 8, 10].contains(pitch % 12)
                    context.fill(Path(CGRect(x: left, y: y, width: width, height: row)), with: .color(.primary.opacity(black ? 0.055 : 0.015)))
                    context.fill(Path(CGRect(x: 0, y: y, width: left - 1, height: max(1, row - 0.5))), with: .color(black ? .secondary.opacity(0.35) : .secondary.opacity(0.1)))
                    if pitch % 12 == 0 {
                        context.draw(Text("C\(pitch / 12 - 1)").font(.system(size: 9)).foregroundColor(.secondary), at: CGPoint(x: 18, y: y + row / 2))
                    }
                }
                let step = span > 30 ? 10.0 : (span > 10 ? 5 : 1)
                for t in stride(from: floor(start / step) * step, through: start + span, by: step) {
                    let x = left + (t - start) / span * width
                    guard x >= left else { continue }
                    context.fill(Path(CGRect(x: x, y: top, width: 0.5, height: size.height - top)), with: .color(.secondary.opacity(0.25)))
                    context.draw(Text(PlayerModel.clock(t)).font(.system(size: 10).monospacedDigit()).foregroundColor(.secondary), at: CGPoint(x: x + 3, y: 12), anchor: .leading)
                }
                for note in song.visibleNotes(from: start, through: start + span) where note.end >= start && note.start <= start + span && !hidden.contains(note.track) {
                    let x = max(left, left + (note.start - start) / span * width)
                    let end = min(size.width, left + (note.end - start) / span * width)
                    let rect = CGRect(x: x, y: top + Double(high - note.pitch) * row + 0.7, width: max(2, end - x), height: max(2, row - 1.4))
                    context.fill(Path(roundedRect: rect, cornerRadius: min(3, row / 3)), with: .color(Self.colors[note.track % Self.colors.count].opacity(0.5 + Double(note.velocity) / 254)))
                }
                let x = left + (position - start) / span * width
                context.fill(Path(CGRect(x: x, y: top, width: 2, height: size.height - top)), with: .color(.red))
                var head = Path(); head.move(to: CGPoint(x: x - 5, y: top - 7)); head.addLine(to: CGPoint(x: x + 5, y: top - 7)); head.addLine(to: CGPoint(x: x, y: top)); head.closeSubpath()
                context.fill(head, with: .color(.red))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if dragOrigin == nil { dragOrigin = start }
                seek(min(song.duration, max(0, (dragOrigin ?? start) + (value.location.x - left) / width * span)))
            }.onEnded { _ in dragOrigin = nil })
            .accessibilityLabel(L("pianoRoll"))
            .accessibilityValue(PlayerModel.clock(position))
            .accessibilityAdjustableAction { direction in seek(min(song.duration, max(0, position + (direction == .increment ? 1 : -1)))) }
        }
    }
}
