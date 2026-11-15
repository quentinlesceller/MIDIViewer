import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let model = PlayerModel()
    var window: NSWindow?
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil); return true
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { Self.model.pause(); sender.orderOut(nil); return false }
    func applicationWillTerminate(_ notification: Notification) { Self.model.stop() }
}
@main struct MIDIViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppDelegate.model
    var body: some Scene {
        WindowGroup("MIDI Viewer", id: "main") {
            ContentView(model: model)
                .onOpenURL { model.open($0) }
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .background(WindowHook(url: model.url, delegate: delegate))
                .frame(minWidth: 720, minHeight: 420)
        }
        .handlesExternalEvents(matching: ["*"])
        .defaultSize(width: 980, height: 640)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("open")) { model.openPanel() }.keyboardShortcut("o")
            }
            CommandMenu(L("playback")) {
                Button(L(model.playing ? "pause" : "play")) { model.toggle() }.keyboardShortcut(.space, modifiers: []).disabled(model.song == nil || model.loading)
                Button(L("stop")) { model.stop() }.keyboardShortcut(".").disabled(model.song == nil)
                Divider()
                Button(L("backward")) { model.seek(max(0, model.position - 5)) }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button(L("forward")) { model.seek(min(model.song?.duration ?? 0, model.position + 5)) }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button(L("normalSpeed")) { model.speed = 1 }.keyboardShortcut("0")
            }
            CommandGroup(after: .toolbar) {
                Button(L("zoomIn")) { model.zoom = min(8, model.zoom * 1.5) }.keyboardShortcut("+")
                Button(L("zoomOut")) { model.zoom = max(0.25, model.zoom / 1.5) }.keyboardShortcut("-")
            }
            CommandGroup(replacing: .help) {
                Button(L("help")) {
                    let alert = NSAlert(); alert.messageText = "MIDI Viewer"; alert.informativeText = L("help.text"); alert.runModal()
                }
            }
        }
    }
}
struct WindowHook: NSViewRepresentable {
    let url: URL?
    let delegate: AppDelegate
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if let primary = delegate.window, primary !== window {
                // SwiftUI may create a document-event window. Keep one shared player window.
                window.close()
                primary.title = url?.lastPathComponent ?? "MIDI Viewer"
                primary.representedURL = url
                primary.makeKeyAndOrderFront(nil)
                return
            }
            delegate.window = window; window.delegate = delegate
            window.title = url?.lastPathComponent ?? "MIDI Viewer"
            window.representedURL = url
        }
    }
}
