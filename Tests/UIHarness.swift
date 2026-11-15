// Optional visual QA harness: same production views at the minimum size in dark mode.
// Compile with Tools/ui-smoke.sh; never included in the release application.
import SwiftUI
@main struct UIHarness: App {
    @StateObject private var model = PlayerModel()
    var body: some Scene {
        WindowGroup("MIDI Viewer — UI QA") {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 720, maxWidth: 720, minHeight: 420, maxHeight: 420)
                .onAppear {
                    if let path = ProcessInfo.processInfo.environment["MIDI_QA_FILE"] { model.open(URL(fileURLWithPath: path)) }
                }
        }.defaultSize(width: 720, height: 420).windowToolbarStyle(.unifiedCompact)
    }
}
