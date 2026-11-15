import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: PlayerModel
    @State private var targeted = false
    var body: some View {
        VStack(spacing: 0) {
            if let song = model.song {
                HSplitView {
                    ScrollView { LazyVStack(alignment: .leading, spacing: 2) { ForEach(song.tracks) { track in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 7) {
                                Circle().fill(PianoRoll.colors[track.id % PianoRoll.colors.count]).frame(width: 7, height: 7)
                                Text(model.name(track)).lineLimit(2).help(model.name(track))
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 12) {
                                Text(track.noteCount, format: .number).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Image(systemName: "music.note").font(.caption).foregroundStyle(.secondary).accessibilityLabel(L("notes"))
                                Spacer(minLength: 0)
                                trackButton(model.hidden.contains(track.id) ? "eye.slash" : "eye", label: "visibility", track: track) {
                                    if !model.hidden.insert(track.id).inserted { model.hidden.remove(track.id) }
                                }
                                trackButton(model.muted.contains(track.id) ? "speaker.slash.fill" : "speaker.wave.2", label: "mute", track: track) {
                                    if !model.muted.insert(track.id).inserted { model.muted.remove(track.id) }
                                }
                                Button { model.solo = model.solo == track.id ? nil : track.id } label: {
                                    Image(systemName: model.solo == track.id ? "headphones.circle.fill" : "headphones.circle")
                                }.buttonStyle(.borderless).help(L("solo")).accessibilityLabel(L("solo") + ": " + model.name(track))
                                    .accessibilityValue(model.solo == track.id ? L("on") : L("off"))
                            }
                        }.padding(.vertical, 9).padding(.horizontal, 14).accessibilityElement(children: .contain)
                    } }.padding(.vertical, 6) }.background(.bar).frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
                    PianoRoll(song: song, position: model.position, zoom: model.zoom, hidden: model.hidden, seek: model.seek)
                        .frame(minWidth: 450)
                }
                Divider()
                HStack(spacing: 10) {
                    Text(PlayerModel.clock(model.position)).monospacedDigit().frame(width: 48, alignment: .trailing)
                    Slider(value: Binding(get: { model.position }, set: model.seek), in: 0...song.duration)
                        .accessibilityLabel(L("position"))
                    Text(PlayerModel.clock(song.duration)).monospacedDigit().foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
                }.padding(.horizontal, 18).padding(.vertical, 10)
            } else {
                Spacer()
                Image(systemName: "pianokeys").font(.system(size: 58, weight: .light)).foregroundStyle(.tint).padding(.bottom, 12)
                Text(L("welcome")).font(.title2.weight(.semibold))
                Text(L("dropHint")).foregroundStyle(.secondary).padding(.top, 4)
                Button(L("open"), action: model.openPanel).keyboardShortcut("o").padding(.top, 16)
                Spacer()
                Text(L("offline")).font(.caption).foregroundStyle(.secondary).padding(22)
            }
        }
        .overlay { if targeted { RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3).padding(5).allowsHitTesting(false) } }
        .overlay { if model.loading { ZStack { Color(nsColor: .windowBackgroundColor).opacity(0.88); ProgressView(L("loading")) } } }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: model.openPanel) { Image(systemName: "folder") }.help(L("open")).accessibilityLabel(L("open"))
            }
            ToolbarItemGroup(placement: .principal) {
                Button(action: model.stop) { Image(systemName: "backward.end.fill") }.help(L("stop")).accessibilityLabel(L("stop")).disabled(model.song == nil || model.loading)
                Button(action: model.toggle) { Image(systemName: model.playing ? "pause.fill" : "play.fill") }.help(L(model.playing ? "pause" : "play")).accessibilityLabel(L(model.playing ? "pause" : "play")).disabled(model.song == nil || model.loading)
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button { model.speed = speed } label: { Text(speed, format: .percent.precision(.fractionLength(0))); if model.speed == speed { Image(systemName: "checkmark") } }
                    }
                } label: { Text(model.speed, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
                .help(L("speed")).accessibilityLabel(L("speed"))
            }
            ToolbarItemGroup(placement: .automatic) {
                Image(systemName: "speaker.wave.2").help(L("volume")).accessibilityHidden(true)
                Slider(value: $model.volume, in: 0...1).frame(width: 75).help(L("volume")).accessibilityLabel(L("volume"))
                Menu {
                    Button(L("zoomIn")) { model.zoom = min(8, model.zoom * 1.5) }
                    Button(L("zoomOut")) { model.zoom = max(0.25, model.zoom / 1.5) }
                    Button(L("zoomReset")) { model.zoom = 1 }
                } label: { Image(systemName: "plus.magnifyingglass") }.help(L("zoom")).accessibilityLabel(L("zoom"))
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in model.open(url) } }
            }; return true
        }
        .alert(L("error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L("ok"), role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private func trackButton(_ image: String, label: String, track: MIDITrack, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: image) }.buttonStyle(.borderless)
            .help(L(label)).accessibilityLabel(L(label) + ": " + model.name(track))
            .accessibilityValue((label == "mute" ? model.muted.contains(track.id) : !model.hidden.contains(track.id)) ? L("on") : L("off"))
    }
}
