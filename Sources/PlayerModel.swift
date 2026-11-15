import SwiftUI
import AppKit
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor final class PlayerModel: ObservableObject {
    @Published var song: MIDIFile?
    @Published var url: URL?
    @Published var loading = false
    @Published var error: String?
    @Published var position = 0.0
    @Published var playing = false
    @Published var volume = 0.75 { didSet { player?.setVolume(Float(volume)) } }
    @Published var speed = 1.0 { didSet { player?.setSpeed(speed) } }
    @Published var zoom = 1.0
    @Published var hidden = Set<Int>()
    @Published var muted = Set<Int>() { didSet { updateMute() } }
    @Published var solo: Int? { didSet { updateMute() } }
    private var player: AudioPlayer?
    private var generation = UUID()
    private var timer: Timer?
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                let state = player.snapshot(); self.position = state.0; self.playing = state.1
            }
        }
    }
    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "mid") ?? .data, UTType(filenameExtension: "midi") ?? .data]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.begin { [weak self] result in
            if result == .OK, let url = panel.url { Task { @MainActor in self?.open(url) } }
        }
    }
    func open(_ fileURL: URL) {
        player?.stop(); playing = false
        generation = UUID(); let token = generation
        loading = true
        Task {
            do {
                let file = try await Task.detached(priority: .userInitiated) {
                    let granted = fileURL.startAccessingSecurityScopedResource()
                    defer { if granted { fileURL.stopAccessingSecurityScopedResource() } }
                    return try MIDIFile.load(fileURL)
                }.value
                guard token == generation else { return }
                if player == nil { player = try AudioPlayer() }
                player?.load(file); player?.setVolume(Float(volume)); player?.setSpeed(speed)
                song = file; url = fileURL; position = 0; hidden = []; muted = []; solo = nil
                NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
            } catch {
                guard token == generation else { return }
                if let midiError = error as? MIDIError { self.error = midiError.localizedDescription }
                else { self.error = L("error.open") + "\n" + error.localizedDescription }
            }
            loading = false
        }
    }
    func toggle() { guard !loading else { return }; player?.playPause() }
    func stop() { player?.stop(); position = 0; playing = false }
    func pause() { player?.pause(); playing = false }
    func seek(_ time: Double) { player?.seek(time); position = time }
    func name(_ track: MIDITrack) -> String { track.name.isEmpty ? String(format: L("track.number"), track.id + 1) : track.name }
    private func updateMute() {
        var result = muted
        if let solo { for track in song?.tracks ?? [] where track.id != solo { result.insert(track.id) } }
        player?.setMuted(result)
    }
    static func clock(_ value: Double) -> String {
        let n = max(0, Int(value)); return String(format: "%d:%02d", n / 60, n % 60)
    }
}
