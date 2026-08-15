import SwiftUI

/// Vor/Zurück-Blättern mit Seitenanzeige für lange Listen – gemeinsam
/// genutzt von `FuelEntryListWindow` und `ExpenseListWindow`, damit beide
/// Listen sich gleich verhalten und aussehen.
struct PaginationControls: View {
    @Binding var currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack {
            Button("Zurück", systemImage: "chevron.left") {
                currentPage -= 1
            }
            .buttonStyle(.glass)
            .disabled(currentPage == 0)
            .pointerStyle(currentPage == 0 ? nil : .link)

            Spacer()

            Text("Seite \(currentPage + 1) von \(totalPages)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                currentPage += 1
            } label: {
                HStack(spacing: 4) {
                    Text("Weiter")
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.glass)
            .disabled(currentPage >= totalPages - 1)
            .pointerStyle(currentPage >= totalPages - 1 ? nil : .link)
        }
        .frame(maxWidth: .infinity)
    }
}
