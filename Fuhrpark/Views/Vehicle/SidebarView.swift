import SwiftUI
import CoreData

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppCommands.self) private var appCommands
    @Binding var selection: SidebarSelection

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Vehicle.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Vehicle.licensePlate, ascending: true)
        ],
        animation: .default
    )
    private var vehicles: FetchedResults<Vehicle>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isDone == NO"),
        animation: .default
    )
    private var openReminders: FetchedResults<Erinnerung>

    @State private var isPresentingNewVehicle = false
    @State private var isPresentingSectionConfig = false
    @State private var vehiclePendingDeletion: Vehicle?
    @State private var isGeneralExpanded = true
    @State private var isVehiclesExpanded = true
    @State private var isDecommissionedExpanded = true
    /// Welche der optionalen „Allgemein"-Zeilen sichtbar sind, aus den
    /// UserDefaults vorbelegt (siehe `SidebarSectionVisibilityStore`).
    @State private var enabledSections = SidebarSectionVisibilityStore.enabledSections()

    /// Anzahl offener Erinnerungen, die bereits fällig sind (siehe `Erinnerung.isDue`).
    /// Liest `dailyDueCheckTick` mit, damit der Badge auch ohne Klick oder
    /// Datenänderung einmal täglich neu berechnet wird (siehe dort).
    private var dueReminderCount: Int {
        _ = appCommands.dailyDueCheckTick
        return openReminders.filter(\.isDue).count
    }

    /// Aktive Fahrzeuge in der vom Nutzer per Drag&Drop festgelegten
    /// Reihenfolge (`sortOrder`, siehe `moveActiveVehicles`).
    private var activeVehicles: [Vehicle] {
        vehicles.filter { !$0.decommissioned }
    }

    /// Übernimmt eine per Drag&Drop geänderte Reihenfolge: die komplette
    /// aktive Liste wird dabei lückenlos neu durchnummeriert (0…n-1), statt
    /// nur die verschobenen Fahrzeuge anzupassen – einfacher und robust
    /// gegen Kollisionen, da `sortOrder` sonst schnell an mehreren Stellen
    /// gleichzeitig verschoben werden müsste.
    ///
    /// `.onMove` erkannte auf macOS überhaupt keine Ziehgeste (kein
    /// Geist-Bild, keinerlei Reaktion) – Ursache war, dass die Liste ohne
    /// eigene `selection:`-Bindung lief; die zeilenweise Auswahl passierte
    /// bisher per eigenem `Button`/`.onTapGesture`. AppKits Zeilen-Drag ist
    /// an die native Listenauswahl gekoppelt (siehe `listSelectionBinding`
    /// unten) – erst mit `List(selection:)` und `.tag(...)` auf den Zeilen
    /// beginnt `.onMove` überhaupt, Drag-Gesten zu erkennen.
    private func moveActiveVehicles(from source: IndexSet, to destination: Int) {
        var reordered = activeVehicles
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, vehicle) in reordered.enumerated() {
            vehicle.sortOrder = Int32(index)
        }
        PersistenceController.shared.save(context: viewContext)
    }

    /// Bindung für `List(selection:)`: macOS koppelt die native
    /// Zeilen-Drag-Erkennung an die eingebaute Listenauswahl, die eine
    /// optionale Auswahl erwartet. `selection` selbst bleibt nicht-optional
    /// (irgendetwas ist immer ausgewählt) – ein `nil` von der Liste (z. B.
    /// bei Klick ins Leere) fällt deshalb zurück auf „Statistik“.
    private var listSelectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? .statistics }
        )
    }

    /// Stillgelegte Fahrzeuge, alphabetisch nach Kennzeichen.
    private var decommissionedVehicles: [Vehicle] {
        vehicles
            .filter(\.decommissioned)
            .sorted { ($0.licensePlate ?? "") < ($1.licensePlate ?? "") }
    }

    /// Die zur aktuellen Auswahl gehörende ausblendbare Zeile, oder `nil` bei
    /// „Statistik" oder einem Fahrzeug – beide sind nicht Teil der
    /// Konfiguration.
    private var sectionOfSelection: SidebarSection? {
        switch selection {
        case .documents: return .documents
        case .notes: return .notes
        case .reminders: return .reminders
        case .fuelPrices: return .fuelPrices
        case .mcp: return .mcp
        case .statistics, .vehicle: return nil
        }
    }

    /// Ein-/Ausblenden einer Zeile, sofort persistiert.
    private func sectionBinding(_ section: SidebarSection) -> Binding<Bool> {
        Binding(
            get: { enabledSections.contains(section) },
            set: { isOn in
                if isOn { enabledSections.insert(section) } else { enabledSections.remove(section) }
                SidebarSectionVisibilityStore.setEnabledSections(enabledSections)
            }
        )
    }

    private var sectionVisibilityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sichtbare Menüpunkte")
                .font(.headline)
            ForEach(SidebarSection.allCases) { section in
                Toggle(section.title, isOn: sectionBinding(section))
                    .toggleStyle(.checkbox)
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
    }

    var body: some View {
        list
            .navigationTitle("Fuhrpark")
            .toolbar {
                ToolbarItem {
                    Button {
                        isPresentingNewVehicle = true
                    } label: {
                        Label("Neues Fahrzeug", systemImage: "plus")
                    }
                    .pointerStyle(.link)
                }
                ToolbarItem {
                    Button {
                        isPresentingSectionConfig = true
                    } label: {
                        Label("Menüpunkte konfigurieren", systemImage: "gearshape")
                    }
                    .pointerStyle(.link)
                    .popover(isPresented: $isPresentingSectionConfig) {
                        sectionVisibilityPopover
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewVehicle) {
                VehicleFormView()
            }
            .onChange(of: enabledSections) { _, newValue in
                if let sectionOfSelection, !newValue.contains(sectionOfSelection) {
                    selection = .statistics
                }
            }
            .modifier(VehicleConfirmationModifier(
                pending: $vehiclePendingDeletion,
                title: "Fahrzeug wirklich löschen?",
                actionLabel: "Löschen",
                actionRole: .destructive,
                message: { "„\($0.licensePlate ?? "")“ und alle zugehörigen \($0.engineType.refuelNounPlural), Ausgaben, Erinnerungen und Notizen werden unwiderruflich gelöscht." },
                action: delete
            ))
    }

    private var list: some View {
        List(selection: listSelectionBinding) {
            Section(isExpanded: $isGeneralExpanded) {
                Button {
                    selection = .statistics
                } label: {
                    sidebarLabel("Statistik", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .listRowBackground(rowBackground(for: .statistics))

                if enabledSections.contains(.documents) {
                    Button {
                        selection = .documents
                    } label: {
                        sidebarLabel("Dokumente", systemImage: "folder.fill")
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .listRowBackground(rowBackground(for: .documents))
                }

                if enabledSections.contains(.notes) {
                    Button {
                        selection = .notes
                    } label: {
                        sidebarLabel("Notizen", systemImage: "note.text")
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .listRowBackground(rowBackground(for: .notes))
                }

                if enabledSections.contains(.reminders) {
                    Button {
                        selection = .reminders
                    } label: {
                        HStack {
                            sidebarLabel("Erinnerungen", systemImage: "bell.fill")
                            Spacer()
                            if dueReminderCount > 0 {
                                ReminderCountBadge(count: dueReminderCount)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .listRowBackground(rowBackground(for: .reminders))
                }

                if enabledSections.contains(.fuelPrices) {
                    Button {
                        selection = .fuelPrices
                    } label: {
                        sidebarLabel("Spritpreise", systemImage: "fuelpump.circle")
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .listRowBackground(rowBackground(for: .fuelPrices))
                }

                if enabledSections.contains(.mcp) {
                    Button {
                        selection = .mcp
                    } label: {
                        sidebarLabel("KI-Zugriff", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .listRowBackground(rowBackground(for: .mcp))
                }
            } header: {
                Text("Allgemein")
            }

            Section(isExpanded: $isVehiclesExpanded) {
                ForEach(activeVehicles) { vehicle in
                    vehicleRow(vehicle)
                }
                .onDelete { offsets in
                    for index in offsets {
                        vehiclePendingDeletion = activeVehicles[index]
                    }
                }
                .onMove(perform: moveActiveVehicles)
            } header: {
                sectionHeader("Fahrzeuge", count: activeVehicles.count)
            }

            if !decommissionedVehicles.isEmpty {
                Section(isExpanded: $isDecommissionedExpanded) {
                    ForEach(decommissionedVehicles) { vehicle in
                        vehicleRow(vehicle)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            vehiclePendingDeletion = decommissionedVehicles[index]
                        }
                    }
                } header: {
                    sectionHeader("Stillgelegte Fahrzeuge", count: decommissionedVehicles.count)
                }
            }
        }
    }

    /// Zeilen-Label für die „Allgemein"-Einträge mit blauem Icon.
    private func sidebarLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
    }

    /// Section-Header mit Titel und Anzahl, für die auf-/zuklappbaren
    /// Fahrzeug-Sektionen.
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.tertiary)
                .padding(.trailing, 18)
        }
    }

    /// Kein `Button`/`.onTapGesture` (wie sonst in dieser Datei) – die Zeile
    /// nutzt stattdessen `.tag(...)` und die native Listenauswahl
    /// (`listSelectionBinding`), weil AppKits Zeilen-Drag für `.onMove` nur
    /// darüber überhaupt aktiv wird. Deshalb auch kein eigener
    /// `rowBackground`-Tint mehr hier: die native macOS-Auswahlhervorhebung
    /// übernimmt das.
    @ViewBuilder
    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        VehicleRow(vehicle: vehicle)
            .tag(SidebarSelection.vehicle(vehicle))
    }

    private func rowBackground(for item: SidebarSelection) -> Color {
        selection == item ? Color.accentColor.opacity(0.2) : Color.clear
    }

    private func delete(_ vehicle: Vehicle) {
        if selection == .vehicle(vehicle) {
            selection = .statistics
        }
        vehicle.delete(in: viewContext)
    }
}

/// Wiederverwendbarer Bestätigungsdialog für eine Fahrzeug-Aktion (Löschen bzw.
/// Stilllegen). Als eigener `ViewModifier`, damit die aufrufende View schlank
/// und für den Type-Checker handhabbar bleibt. Wird von `SidebarView` (Löschen
/// per Wisch-Geste) und `VehicleDetailView` (Aktionsmenü) genutzt.
struct VehicleConfirmationModifier: ViewModifier {
    @Binding var pending: Vehicle?
    let title: String
    let actionLabel: String
    let actionRole: ButtonRole?
    let message: (Vehicle) -> String
    let action: (Vehicle) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            presenting: pending
        ) { vehicle in
            Button(actionLabel, role: actionRole) { action(vehicle) }
            Button("Abbrechen", role: .cancel) { }
        } message: { vehicle in
            Text(message(vehicle))
        }
    }
}

private struct VehicleRow: View {
    @ObservedObject var vehicle: Vehicle

    private var dimmed: Double { vehicle.decommissioned ? 0.5 : 1 }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle.licensePlate ?? "")
                        .font(.headline)
                        .opacity(dimmed)
                    if vehicle.decommissioned {
                        DecommissionedBadge()
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Anfangsstand: \(DisplayFormatter.odometerString(vehicle.odometer)) km")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Höchststand: \(DisplayFormatter.odometerString(vehicle.highestOdometer)) km")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .opacity(dimmed)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.leading, 5)
        .contentShape(Rectangle())
    }
}

/// Rote „Stillgelegt"-Marke. Adaptives System-Rot (Dark: heller, Light: satter),
/// daher auf hellem und dunklem Hintergrund gut lesbar.
struct DecommissionedBadge: View {
    var showsIcon = false

    var body: some View {
        Group {
            if showsIcon {
                Label("Stillgelegt", systemImage: "xmark.seal.fill")
            } else {
                Text("Stillgelegt")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.red)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.red.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(.red.opacity(0.4), lineWidth: 0.5))
    }
}

/// Rote numerische Marke für die Anzahl fälliger Erinnerungen.
struct ReminderCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
    }
}
