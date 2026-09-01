import AppKit
import Observation

/// Steuert das Erscheinungsbild der gesamten App (Hell/Dunkel/System) über
/// `NSApp.appearance` statt über SwiftUIs `.preferredColorScheme` an jeder
/// einzelnen Szenen-Wurzel. Diese App hat mehrere unabhängige Fenster-Szenen
/// (Haupt-, Listen-, Chart-Fenster), ein Sheet (`SettingsView`) und ein
/// Menüleisten-Popover (`MenuBarExtra`) – jede davon bräuchte den Modifier
/// einzeln, und native Elemente wie `NSOpenPanel`/`NSSavePanel` oder die
/// Fenster-Titelleisten reagieren darauf ohnehin nicht. `NSApp.appearance`
/// ist dagegen die App-weite Vorgabe, von der jedes Fenster (SwiftUI wie
/// AppKit) erbt, solange es nicht selbst etwas anderes festlegt – deckt also
/// zuverlässig alles auf einmal ab.
@MainActor
@Observable
final class AppearanceSettings {
    var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            AppearanceModeStore.set(mode)
            apply()
        }
    }

    init() {
        mode = AppearanceModeStore.get()
        // `NSApp` existiert an dieser Stelle noch nicht: SwiftUI konstruiert
        // `FuhrparkDesktopApp` samt seiner `@State`-Startwerte, bevor es
        // `NSApplication` aufsetzt – ein direkter Aufruf von `apply()` hier
        // stürzte beim Start mit einem Nil-Unwrap auf `NSApp` ab. Die erste
        // Anwendung deshalb erst, sobald der Start abgeschlossen ist.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.apply()
            }
        }
    }

    private func apply() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
