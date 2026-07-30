# FuhrparkDesktop für macOS

[![GitHub](https://img.shields.io/badge/Lizenz-MIT-orange)](https://github.com/harfromgol/FuhrparkDesktop/blob/main/LICENSE) [![GitHub](https://img.shields.io/badge/Version-v1%2E3-blue)](https://github.com/harfromgol/FuhrparkDesktop/releases)

Native macOS-App (SwiftUI + Core Data) zur Verwaltung eines kleinen Fuhrparks:
Fahrzeuge, Betankungen, sonstige Ausgaben, Belege und Spritpreise an einem Ort.

> [!WARNING]
> Dies ist ein reines vibe - coding Projekt, weil ich die Möglichkeiten von Claude Code antesten wollte, d.h. die App und die zugeörige Webseite sind komplett KI generiert. Nutzung auf eigene Gefahr! :)

## Funktionen

- **Fahrzeugverwaltung** – Kennzeichen, Hersteller, Modell, Tachostand; Kennzeichen
  werden beim Anlegen auf Duplikate geprüft (stillgelegte Fahrzeuge blockieren ihr
  Kennzeichen nicht, ein Nachfolgefahrzeug darf es erneut nutzen).
- **Fahrzeug stilllegen** – stillgelegte Fahrzeuge erscheinen in einer eigenen
  Sidebar-Sektion, können keine Betankungen mehr erfassen (sonstige Ausgaben
  weiterhin) und lassen sich nicht reaktivieren.
- **Betankungen** – Menge, Preis, Verbrauch (automatisch oder manuell), Historie
  mit Verlaufs-Charts.
- **Sonstige Ausgaben/Einnahmen** – mit frei definierbaren Kategorien und
  Empfänger-Autovervollständigung.
- **Dokumente** – Belege (PDF, Fotos, …) einer Ausgabe zuordnen, zentrale
  Dokumenten-Übersicht mit Filter nach Fahrzeug/Kategorie.
- **Erinnerungen** - laß Dich an den nächsten TÜV Termin oder an die fällige Versicherung/Steuer erinnern
- **Statistik** – Kosten pro Kategorie, pro Jahr, pro Fahrzeug.
- **Spritpreise** – Umkreissuche über die Tankerkönig-API (eigener API-Key
  erforderlich, wird lokal gespeichert und nicht mit exportiert).
- **Datenexport/-import** – vollständiges JSON-Backup aller Fahrzeuge,
  Betankungen, Ausgaben, Kategorien und Dokumente (`Tools → Daten exportieren
  / importieren`).

## Voraussetzungen

- macOS 26 oder neuer
- Xcode (aktuelle Version)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Datenschutz

Alle eingegebenen Daten bleiben auf deinem Rechner. Es werden keinerlei Daten in die Cloud gesendet.

Ausnahme: der Tankerkönig-API Key - falls eingegeben - muss natürlich an den Tankerkönig Server gesendet werden, sonst funktioniert die Tankstellen Umkreissuche nicht.

## Projekt einrichten & starten

Das `.xcodeproj` wird nicht versioniert, sondern aus `project.yml` generiert:

```bash
xcodegen generate
open FuhrparkDesktop.xcodeproj
```

Alternativ per Kommandozeile bauen:

```bash
xcodegen generate
xcodebuild -project FuhrparkDesktop.xcodeproj -scheme FuhrparkDesktop -configuration Debug build
```

## Projektstruktur

```
Fuhrpark/
  App/           Einstiegspunkt, Menüleiste, ContentView
  Models/        Core-Data-Modell (Fuhrpark.xcdatamodeld) + Extensions
  Persistence/    Core-Data-Stack, Export/Import, Key/Value-Stores
  Services/       Standort, Tankerkönig-API
  Views/          SwiftUI-Views, gegliedert nach Fahrzeug/Betankung/Ausgabe/…
FuhrparkDesktop/  App-Target-Ressourcen (Info.plist, Entitlements, Assets)
Scripts/          Release-/DMG-Build, Icon- und Hintergrundbild-Generierung
project.yml       XcodeGen-Projektdefinition
```

## Release-Build (DMG)

```bash
Scripts/build_dmg.sh
```

Erzeugt ein installierbares DMG unter `dist/FuhrparkDesktop-<Version>.dmg`.

## Kontakt

Solltest Du Fragen, Anregungen etc. haben, dann darfst Du gerne [Kontakt](mailto:nospam@gerd-klaus.de) zu mir aufnehmen. Wenn es meine Zeit zulässt, werde ich gerne weiterhelfen.
