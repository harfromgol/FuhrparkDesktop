# FuhrparkDesktop für macOS

[![Codeberg](https://img.shields.io/badge/Lizenz-MIT-orange)](https://codeberg.org/Gerd/fuhrpark-macos/src/branch/develop/LICENSE)
[![Codeberg](https://img.shields.io/badge/Version-v1%2E1-blue)](https://codeberg.org/Gerd/fuhrpark-macos/releases)


Native macOS-App (SwiftUI + Core Data) zur Verwaltung eines kleinen Fuhrparks:
Fahrzeuge, Betankungen, sonstige Ausgaben, Belege und Spritpreise an einem Ort.

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

Solltest Du Fragen, Anregungen, Drohungen etc. haben, dann darfst Du gerne [Kontakt](mailto:nospam@gerd-klaus.de) zu mir aufnehmen. Wenn es meine Zeit zulässt, werde ich gerne weiterhelfen.
