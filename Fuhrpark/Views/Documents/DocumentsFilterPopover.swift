import SwiftUI

/// Einfachauswahl für den Fahrzeugstatus im Dokumente-Filter.
enum FahrzeugStatusFilter: String, CaseIterable, Identifiable {
    case alle, aktiv, stillgelegt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alle: "Alle"
        case .aktiv: "Aktiv"
        case .stillgelegt: "Stillgelegt"
        }
    }
}

/// Filtereinstellungen für die Dokumente-Ansicht, geöffnet über das
/// Filter-Symbol neben dem Zahnrad. Die vier Filter verunden sich und
/// kaskadieren in dieser Reihenfolge: Fahrzeugstatus schränkt die
/// wählbaren Fahrzeuge ein, beide zusammen schränken die wählbaren
/// Kategorien ein. `availableVehicles`/`availableCategoryNames` kommen
/// dafür bereits vorgefiltert von `DocumentsView` herein – diese Ansicht
/// rechnet selbst nichts nach.
struct DocumentsFilterPopover: View {
    @Binding var statusFilter: FahrzeugStatusFilter
    @Binding var selectedVehicleFilter: Set<Vehicle>
    @Binding var selectedCategoryFilter: Set<String>
    @Binding var isDateFilterActive: Bool
    @Binding var dateFrom: Date
    @Binding var dateTo: Date

    let availableVehicles: [Vehicle]
    let availableCategoryNames: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Filter")
                        .font(.headline)
                    Spacer()
                    Button("Zurücksetzen") {
                        statusFilter = .alle
                        selectedVehicleFilter.removeAll()
                        selectedCategoryFilter.removeAll()
                        isDateFilterActive = false
                    }
                    .buttonStyle(.borderless)
                    .pointerStyle(.link)
                }

                Picker("Fahrzeugstatus", selection: $statusFilter) {
                    ForEach(FahrzeugStatusFilter.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if !availableVehicles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fahrzeug")
                            .font(.subheadline.bold())
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            filterChip(title: "Alle", selected: selectedVehicleFilter.isEmpty) {
                                selectedVehicleFilter.removeAll()
                            }
                            ForEach(availableVehicles) { vehicle in
                                filterChip(
                                    title: vehicle.licensePlate ?? "",
                                    selected: selectedVehicleFilter.contains(vehicle)
                                ) {
                                    if selectedVehicleFilter.contains(vehicle) {
                                        selectedVehicleFilter.remove(vehicle)
                                    } else {
                                        selectedVehicleFilter.insert(vehicle)
                                    }
                                }
                            }
                        }
                    }
                }

                if !availableCategoryNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategorie")
                            .font(.subheadline.bold())
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            filterChip(title: "Alle", selected: selectedCategoryFilter.isEmpty) {
                                selectedCategoryFilter.removeAll()
                            }
                            ForEach(availableCategoryNames, id: \.self) { name in
                                filterChip(title: name, selected: selectedCategoryFilter.contains(name)) {
                                    if selectedCategoryFilter.contains(name) {
                                        selectedCategoryFilter.remove(name)
                                    } else {
                                        selectedCategoryFilter.insert(name)
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Zeitraum eingrenzen", isOn: $isDateFilterActive)
                        .toggleStyle(.checkbox)
                    if isDateFilterActive {
                        DatePicker(
                            "Von",
                            selection: $dateFrom,
                            in: ...dateTo,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "Bis",
                            selection: $dateTo,
                            in: dateFrom...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 480)
        .frame(width: 340)
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    selected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}
