import SwiftUI

/// Ersetzt den nativen `.menu`-Picker für die Fahrzeugauswahl: gruppiert
/// nach Status (Aktiv/Stillgelegt) mit Überschriften und zeigt je Fahrzeug
/// zwei Zeilen (Kennzeichen + Hersteller/Modell) – beides kann ein
/// natives `Picker`/`NSMenuItem` nicht gleichzeitig, da Menüeinträge nur
/// einen einzelnen Titel pro Zeile kennen. Folgt demselben
/// Button-+-Popover-Muster wie `ExpensePickerSection`/`NotePickerSection`
/// in `NewDocumentAssignmentView.swift`.
struct VehiclePicker: View {
    let vehicles: [Vehicle]
    @Binding var selection: Vehicle?
    var placeholder: String = "Bitte wählen"

    @State private var isPresented = false

    private var activeVehicles: [Vehicle] { vehicles.filter { !$0.decommissioned } }
    private var decommissionedVehicles: [Vehicle] { vehicles.filter(\.decommissioned) }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(selection?.licensePlate ?? placeholder)
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $isPresented) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                placeholderRow
                if !activeVehicles.isEmpty || !decommissionedVehicles.isEmpty {
                    Divider()
                }
                if !activeVehicles.isEmpty {
                    sectionHeader("Aktiv")
                    ForEach(activeVehicles) { vehicleRow($0) }
                }
                if !decommissionedVehicles.isEmpty {
                    sectionHeader("Stillgelegt")
                    ForEach(decommissionedVehicles) { vehicleRow($0) }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .frame(maxHeight: 340)
    }

    private var placeholderRow: some View {
        Button {
            selection = nil
            isPresented = false
        } label: {
            rowContent(isSelected: selection == nil) {
                Text(placeholder)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        Button {
            selection = vehicle
            isPresented = false
        } label: {
            rowContent(isSelected: selection == vehicle) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.licensePlate ?? "")
                        .font(.subheadline.bold())
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    /// Gemeinsamer Rahmen für den Platzhalter- und die Fahrzeug-Zeilen:
    /// Inhalt links, Haken rechts bei aktueller Auswahl.
    @ViewBuilder
    private func rowContent<Content: View>(isSelected: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
