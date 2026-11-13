import SwiftUI
import AppKit

/// Persistiert die vom Nutzer eingestellten Spaltenbreiten je Tabelle in den
/// UserDefaults – Tabellen-Schlüssel → (Spaltentitel → Breite in Punkten).
///
/// Anders als `WindowFrameStore` bewusst **nicht** Teil des JSON-Exports: Der
/// dient dem Datenaustausch mit FuhrparkWeb, und Spaltenbreiten sind dort
/// ohne Bedeutung. In der vollständigen Sicherung sind sie trotzdem
/// enthalten, weil `SettingsSnapshot` den ganzen UserDefaults-Domain sichert.
enum TableColumnWidthStore {
    private static let defaultsKey = "tableColumnWidths"

    private static func all() -> [String: [String: Double]] {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Double]]) ?? [:]
    }

    static func widths(for tableKey: String) -> [String: Double] {
        all()[tableKey] ?? [:]
    }

    static func setWidths(_ widths: [String: Double], for tableKey: String) {
        var tables = all()
        tables[tableKey] = widths
        UserDefaults.standard.set(tables, forKey: defaultsKey)
    }
}

extension View {
    /// Merkt sich die Spaltenbreiten der `Table`, an der dieser Modifier
    /// hängt, unter dem angegebenen Schlüssel und stellt sie wieder her,
    /// sobald die Tabelle (neu) erscheint.
    ///
    /// SwiftUI selbst behält die Breiten nur, solange die Tabelle besteht:
    /// Verschwindet sie kurz – etwa weil ein Filter keine Treffer liefert und
    /// stattdessen ein Hinweistext erscheint – oder wird die App neu
    /// gestartet, stehen wieder alle Spalten gleich breit da.
    /// `TableColumn.width(min:ideal:max:)` hilft dabei nicht, die Vorgaben
    /// bleiben auf diesem SDK-Stand wirkungslos (live geprüft).
    ///
    /// `visibleColumns` sind die Titel der gerade sichtbaren Spalten. Der
    /// Wert wird nicht ausgewertet, er sorgt nur dafür, dass SwiftUI die
    /// Brücke benachrichtigt, wenn eine Spalte ein- oder ausgeblendet wird –
    /// eine wieder eingeblendete Spalte bekommt dann ihre alte Breite zurück.
    func persistColumnWidths(_ key: String, visibleColumns: [String]) -> some View {
        background(TableColumnWidthAccessor(key: key, visibleColumns: visibleColumns))
    }
}

/// Unsichtbare Brücke zu AppKit: findet die `NSTableView` hinter der
/// SwiftUI-`Table` und koppelt sie an einen Koordinator, der Spaltenbreiten
/// wiederherstellt und speichert – nach demselben Muster wie
/// `WindowFrameAccessor`.
private struct TableColumnWidthAccessor: NSViewRepresentable {
    let key: String
    let visibleColumns: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(key: key)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.scheduleSync(anchor: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.scheduleSync(anchor: nsView)
    }

    @MainActor
    final class Coordinator {
        private let key: String
        private weak var anchor: NSView?
        private weak var tableView: NSTableView?

        /// Die Spalten, deren Breite gerade beobachtet wird – als Identitäten,
        /// um zu erkennen, wenn SwiftUI Spalten austauscht (eine wieder
        /// eingeblendete Spalte ist ein neues Objekt).
        private var observedColumns: [ObjectIdentifier] = []
        // Zugriff erfolgt praktisch nur auf dem Main-Thread; `nonisolated(unsafe)`
        // erlaubt das Aufräumen im (nicht isolierten) deinit.
        nonisolated(unsafe) private var observations: [NSKeyValueObservation] = []

        /// Titel der Spalten, deren gespeicherte Breite an der aktuellen
        /// Tabelle bereits gesetzt wurde. Außerhalb der Einschwingphase wird
        /// jede Spalte nur einmal versorgt – beim Einblenden.
        private var appliedColumns = Set<String>()
        /// `true`, während dieser Koordinator selbst Breiten setzt; die
        /// dadurch ausgelösten Beobachtungen sind keine Änderung von außen.
        private var isApplying = false
        /// Einschwingphase nach dem (Neu-)Entstehen der Tabelle, siehe
        /// `beginSettling()`.
        private var isSettling = false
        /// Ob für diese Tabelle Breiten gespeichert sind. Solange der Nutzer
        /// nie eine Spalte gezogen hat, bleibt die Tabelle ganz SwiftUI
        /// überlassen und es wird nichts gespeichert.
        private var hasUserWidths: Bool

        private var settleWorkItem: DispatchWorkItem?
        private var saveWorkItem: DispatchWorkItem?
        /// Verbleibende Wiederholungen, falls die Tabelle beim Abgleich noch
        /// nicht im Fenster steht (siehe `sync()`).
        private var remainingRetries = 0

        init(key: String) {
            self.key = key
            hasUserWidths = !TableColumnWidthStore.widths(for: key).isEmpty
        }

        /// Gleicht die Tabelle im nächsten Runloop-Durchlauf ab und kurz
        /// danach noch einmal: SwiftUI baut Tabelle und Spalten erst nach dem
        /// Aufruf von `makeNSView`/`updateNSView` um, direkt hier wäre der
        /// alte Stand zu sehen.
        func scheduleSync(anchor: NSView) {
            self.anchor = anchor
            remainingRetries = 10
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.sync() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                MainActor.assumeIsolated { self?.sync() }
            }
        }

        private func sync() {
            guard let anchor, let tableView = locateTableView(for: anchor), !tableView.tableColumns.isEmpty else {
                guard remainingRetries > 0 else { return }
                remainingRetries -= 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    MainActor.assumeIsolated { self?.sync() }
                }
                return
            }

            if self.tableView !== tableView {
                self.tableView = tableView
                appliedColumns.removeAll()
                observedColumns.removeAll()
                beginSettling()
            }
            observeColumns(of: tableView)
            applyStoredWidths(force: false)
        }

        /// Sucht im Fenster die `NSTableView`, deren Rollbereich sich am
        /// stärksten mit der Fläche des Ankers deckt. Der Anker liegt als
        /// `background` exakt hinter der SwiftUI-`Table`, hat mit deren
        /// AppKit-Ansichten aber keinen gemeinsamen direkten Elternknoten.
        private func locateTableView(for anchor: NSView) -> NSTableView? {
            guard let root = anchor.window?.contentView else { return nil }
            let anchorFrame = anchor.convert(anchor.bounds, to: nil)
            var best: NSTableView?
            var bestArea: CGFloat = 0

            func visit(_ view: NSView) {
                if let candidate = view as? NSTableView, let scrollView = candidate.enclosingScrollView {
                    let overlap = scrollView.convert(scrollView.bounds, to: nil).intersection(anchorFrame)
                    let area = overlap.isNull ? 0 : overlap.width * overlap.height
                    if area > bestArea {
                        bestArea = area
                        best = candidate
                    }
                }
                view.subviews.forEach(visit)
            }
            visit(root)
            return best
        }

        /// Beobachtet die Breite jeder Spalte per KVO.
        ///
        /// Der übliche Weg, `NSTableView.columnDidResizeNotification`, fällt
        /// aus: SwiftUIs eigene Tabellenklasse verschickt diese
        /// Benachrichtigung nicht, weder beim Ziehen noch sonst (live
        /// geprüft). Die Eigenschaft `width` der Spalten meldet dagegen jede
        /// Änderung.
        private func observeColumns(of tableView: NSTableView) {
            let columns = tableView.tableColumns
            let identities = columns.map(ObjectIdentifier.init)
            guard identities != observedColumns else { return }
            observedColumns = identities
            observations.forEach { $0.invalidate() }
            observations = columns.map { column in
                column.observe(\.width) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.columnWidthDidChange() }
                }
            }
        }

        /// Beginnt die Einschwingphase einer neu entstandenen Tabelle.
        ///
        /// Direkt nach dem Entstehen ändern sich die Breiten noch ohne Zutun
        /// des Nutzers – SwiftUI verteilt die Spalten, und beim Öffnen des
        /// Fensters bekommt es erst danach seine gespeicherte Größe, worauf
        /// AppKit alle Spalten gleichmäßig mitzieht. Solange das andauert,
        /// wird nichts gespeichert; kehrt Ruhe ein, setzt
        /// `finishSettling()` die gespeicherten Breiten endgültig.
        private func beginSettling() {
            isSettling = true
            restartSettleTimer()
        }

        private func restartSettleTimer() {
            settleWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.finishSettling() }
            }
            settleWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }

        private func finishSettling() {
            applyStoredWidths(force: true)
            isSettling = false
        }

        /// Setzt gespeicherte Breiten. Mit `force` für alle Spalten, sonst nur
        /// für die, die an dieser Tabelle noch nicht versorgt wurden – beim
        /// ersten Abgleich also alle, später nur neu eingeblendete.
        private func applyStoredWidths(force: Bool) {
            guard let tableView else { return }
            let stored = TableColumnWidthStore.widths(for: key)
            appliedColumns.formIntersection(tableView.tableColumns.map(\.title))

            isApplying = true
            defer { isApplying = false }

            var didChange = false
            for column in tableView.tableColumns where !column.title.isEmpty {
                guard force || !appliedColumns.contains(column.title) else { continue }
                appliedColumns.insert(column.title)
                guard let storedWidth = stored[column.title] else { continue }
                let width = min(max(CGFloat(storedWidth), column.minWidth), column.maxWidth)
                if abs(column.width - width) > 0.5 {
                    column.width = width
                    didChange = true
                }
            }
            // Die letzte Spalte füllt den Rest – sonst bliebe rechts eine
            // Lücke, wenn etwa eine Spalte mit ihrer alten Breite wieder
            // eingeblendet wurde.
            if didChange {
                tableView.sizeLastColumnToFit()
            }
        }

        private func columnWidthDidChange() {
            guard !isApplying, let tableView else { return }
            if isSettling {
                restartSettleTimer()
                return
            }
            // Gespeichert wird erst, wenn der Nutzer einmal selbst eine Spalte
            // gezogen hat (`resizedColumn`). Von da an aber bei jeder
            // Änderung, also auch, wenn AppKit die Spalten beim Verändern der
            // Fenstergröße mitzieht: Der gespeicherte Stand soll zu der
            // ebenfalls gespeicherten Fenstergröße passen.
            if !hasUserWidths, (tableView.headerView?.resizedColumn ?? -1) >= 0 {
                hasUserWidths = true
            }
            guard hasUserWidths else { return }
            scheduleSave()
        }

        /// Speichert mit kurzer Verzögerung: Beim Ziehen meldet sich jede
        /// Spalte viele Male pro Sekunde, festgehalten werden soll nur der
        /// Endstand.
        private func scheduleSave() {
            saveWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.saveWidths() }
            }
            saveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }

        /// Übernimmt die Breiten der sichtbaren Spalten. Einträge
        /// ausgeblendeter Spalten bleiben stehen, damit diese beim
        /// Wiedereinblenden ihre alte Breite zurückbekommen.
        private func saveWidths() {
            guard let tableView, !isSettling else { return }
            let stored = TableColumnWidthStore.widths(for: key)
            var widths = stored
            for column in tableView.tableColumns where !column.title.isEmpty {
                widths[column.title] = Double(column.width)
            }
            if widths != stored {
                TableColumnWidthStore.setWidths(widths, for: key)
            }
        }

        deinit {
            observations.forEach { $0.invalidate() }
        }
    }
}
