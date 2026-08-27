import SwiftUI

/// Zeile im Apple-Erinnerungen-Stil: Checkbox links, Titel, Fälligkeitsdatum
/// rechts (rot bei überfällig, orange bei fällig durch Vorlaufzeit).
struct ReminderRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppCommands.self) private var appCommands
    @ObservedObject var reminder: Erinnerung
    let onEdit: () -> Void
    let onDelete: () -> Void

    /// Liest `dailyDueCheckTick` mit, damit die Fälligkeits-Farbe auch ohne
    /// Klick oder Datenänderung einmal täglich neu berechnet wird (siehe dort).
    private var dateColor: Color {
        _ = appCommands.dailyDueCheckTick
        if reminder.isOverdue { return .red }
        if reminder.isDue { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                reminder.toggleDone(in: viewContext)
            } label: {
                Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(reminder.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .help(reminder.isDone ? "Als offen markieren" : "Als erledigt markieren")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title ?? "")
                        .font(.subheadline.bold())
                        .strikethrough(reminder.isDone)
                        .foregroundStyle(reminder.isDone ? .secondary : .primary)
                    HStack(spacing: 6) {
                        if let plate = reminder.vehicle?.licensePlate {
                            Text(plate)
                        }
                        if let repeatDescription = reminder.repeatDescription {
                            Text("· \(repeatDescription)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let due = reminder.dueDate {
                    Text(FieldValidator.string(from: due))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(dateColor)
                }
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Bearbeiten", action: onEdit)
            Button("Löschen", role: .destructive, action: onDelete)
        }
    }
}
