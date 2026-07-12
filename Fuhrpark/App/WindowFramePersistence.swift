import SwiftUI
import AppKit

/// Gespeicherte Position und Größe eines Fensters (Bildschirmkoordinaten,
/// Ursprung unten links – wie bei `NSWindow.frame`).
struct WindowFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: NSRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var rect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}

/// Persistiert die Fenster-Frames je Fenster-Schlüssel in den UserDefaults.
/// Wird zusätzlich in den JSON-Export/-Import einbezogen.
enum WindowFrameStore {
    private static let defaultsKey = "windowFrames"

    static func all() -> [String: WindowFrame] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let frames = try? JSONDecoder().decode([String: WindowFrame].self, from: data)
        else { return [:] }
        return frames
    }

    static func frame(for key: String) -> WindowFrame? {
        all()[key]
    }

    static func setFrame(_ frame: WindowFrame, for key: String) {
        var frames = all()
        frames[key] = frame
        persist(frames)
    }

    /// Ersetzt sämtliche gespeicherten Frames (für den Import).
    static func replaceAll(_ frames: [String: WindowFrame]) {
        persist(frames)
    }

    private static func persist(_ frames: [String: WindowFrame]) {
        guard let data = try? JSONEncoder().encode(frames) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

extension View {
    /// Stellt beim Öffnen die zuletzt gespeicherte Position/Größe des Fensters
    /// wieder her und speichert sie bei jeder Änderung sowie beim Schließen unter
    /// dem angegebenen Schlüssel.
    func persistWindowFrame(_ key: String) -> some View {
        background(WindowFrameAccessor(key: key))
    }
}

/// Unsichtbare Brücke zu AppKit: findet das umgebende `NSWindow` und koppelt es
/// an einen Koordinator, der Frame wiederherstellt und speichert.
private struct WindowFrameAccessor: NSViewRepresentable {
    let key: String

    func makeCoordinator() -> Coordinator {
        Coordinator(key: key)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            MainActor.assumeIsolated { context.coordinator.attach(to: view.window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { context.coordinator.attach(to: nsView.window) }
        }
    }

    @MainActor
    final class Coordinator {
        private let key: String
        private weak var window: NSWindow?
        private var didRestore = false
        // Zugriff erfolgt praktisch nur auf dem Main-Thread; `nonisolated(unsafe)`
        // erlaubt das Aufräumen im (nicht isolierten) deinit.
        nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

        init(key: String) {
            self.key = key
        }

        /// Koppelt (einmalig) das Fenster: gespeicherten Frame wiederherstellen und
        /// anschließend Änderungen beobachten.
        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window

            if !didRestore {
                didRestore = true
                if let saved = WindowFrameStore.frame(for: key) {
                    window.setFrame(saved.rect, display: true)
                }
            }

            registerObservers(for: window)
        }

        private func registerObservers(for window: NSWindow) {
            removeObservers()
            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.willCloseNotification] {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.saveFrame() }
                }
                observers.append(token)
            }
        }

        private func saveFrame() {
            guard let window else { return }
            WindowFrameStore.setFrame(WindowFrame(window.frame), for: key)
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            observers.forEach { center.removeObserver($0) }
            observers.removeAll()
        }

        deinit {
            let center = NotificationCenter.default
            observers.forEach { center.removeObserver($0) }
        }
    }
}
