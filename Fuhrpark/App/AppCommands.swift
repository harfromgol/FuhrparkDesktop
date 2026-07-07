import Observation

/// Verbindet Menübefehle (Scene `commands`) mit der Haupt-GUI.
///
/// Menü-Aktionen liegen außerhalb der View-Hierarchie und können daher keine
/// SwiftUI-Dialoge direkt präsentieren. Der Menüpunkt setzt stattdessen ein
/// Flag auf diesem gemeinsamen Objekt; `ContentView` beobachtet es und zeigt
/// die zugehörige Sicherheitsabfrage an.
@MainActor
@Observable
final class AppCommands {
    /// Löst im `ContentView` die Sicherheitsabfrage zum Löschen aller Daten aus.
    var showDeleteAllDataConfirmation = false
}
