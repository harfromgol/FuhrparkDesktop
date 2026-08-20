# FuhrparkDesktop für macOS

[![GitHub](https://img.shields.io/badge/Lizenz-MIT-orange)](https://github.com/harfromgol/FuhrparkDesktop/blob/main/LICENSE) [![GitHub](https://img.shields.io/badge/Version-v1%2E8%2E1-blue)](https://github.com/harfromgol/FuhrparkDesktop/releases)

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
- **Dokumente** – Belege (PDF, Fotos, …) einer oder mehreren sonstigen Ausgaben
  desselben Fahrzeugs zuordnen, auch nachträglich; zentrale Dokumenten-Übersicht
  mit Filter nach Fahrzeug/Kategorie. Die Datei wird dabei nur einmal abgelegt.
- **Erinnerungen** - laß Dich an den nächsten TÜV Termin oder an die fällige Versicherung/Steuer erinnern
- **Statistik** – Kosten pro Kategorie, pro Jahr, pro Fahrzeug.
- **PDF-Export** – Fahrzeugbericht und Statistikübersicht als mehrseitiges
  PDF mit Kopf-/Fußzeile und sauberen Seitenumbrüchen, direkt aus dem
  jeweiligen Aktionsmenü.
- **Spritpreise** – Umkreissuche über die Tankerkönig-API (eigener API-Key
  erforderlich, wird lokal gespeichert und nicht mit exportiert). Angepinnte
  Tankstellen/Sorten lassen sich zusätzlich per Menüleisten-Icon verfolgen.
- **Konfigurierbare Seitenleiste** – Dokumente, Erinnerungen, Spritpreise und
  KI-Zugriff lassen sich einzeln aus der Seitenleiste ausblenden.
- **Datenexport/-import** – vollständiges JSON-Backup aller Fahrzeuge,
  Betankungen, Ausgaben, Kategorien und Dokumente (`Tools → Daten exportieren
  / importieren`).
- **KI-Zugriff (MCP)** – die Daten lassen sich einer KI wie Claude über das
  Model Context Protocol zum Lesen bereitstellen, siehe unten.

## Voraussetzungen

- macOS 26 oder neuer
- Xcode (aktuelle Version)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## KI-Zugriff (MCP)

Die App kann ihre Daten über das
[Model Context Protocol](https://modelcontextprotocol.io) für eine KI wie Claude
lesbar machen. Damit lassen sich Fragen wie „Was kostet mich der Wagen pro
Kilometer?" oder „Was wird demnächst fällig?" direkt im Chat beantworten.

Dazu läuft dasselbe App-Binary wahlweise als GUI oder – mit `--mcp-stdio`
gestartet – als MCP-Server. Weil dieser Prozess die App selbst ist, liest er
die Daten direkt aus deren Datenbank: **ohne Kopie, ohne Zwischendatei und
immer auf aktuellem Stand.** Die App muss dafür nicht laufen.

Einrichtung: in der App auf **KI-Zugriff** in der Seitenleiste gehen. Dort
stehen die fertigen Konfigurationsangaben für Claude Desktop und Claude Code
zum Kopieren, dazu ein Selbsttest, der die Verbindung sofort prüft.

Angeboten werden neun **ausschließlich lesende** Werkzeuge: Flottenübersicht,
Fahrzeugdetails, Listen für Betankungen, Ausgaben, Erinnerungen und Belege,
Kostenauswertung, Volltextsuche und eine Diagnose. Es gibt keinen Weg, über
den die KI Daten anlegen, ändern oder löschen könnte.

## Datenschutz

Alle eingegebenen Daten bleiben auf deinem Rechner. Es werden keinerlei Daten in die Cloud gesendet.

Ausnahme: der Tankerkönig-API Key - falls eingegeben - muss natürlich an den Tankerkönig Server gesendet werden, sonst funktioniert die Tankstellen Umkreissuche nicht.

Zur Update-Prüfung: Die App kann beim Start höchstens einmal täglich
nachsehen, ob eine neue Version vorliegt. Dazu lädt sie eine kleine, für alle
identische Datei von `fuhrpark-macos.gerd-klaus.de` – **ohne** jeden
Parameter, insbesondere ohne die verwendete Version. Beim Webserver landet
dabei nur, was bei jedem Seitenaufruf anfällt (IP-Adresse und Zeitpunkt); ein
Nutzungsprofil lässt sich daraus nicht bilden. Die Prüfung wird beim ersten
Start ausdrücklich erfragt und lässt sich jederzeit im Menü
„FuhrparkDesktop“ → „Automatisch nach Updates suchen“ abschalten. Heruntergeladen
oder installiert wird nichts von selbst – die App verweist nur auf die
Download-Seite.

Zum KI-Zugriff: Er ist nur aktiv, wenn Du ihn selbst in Deinem MCP-Client
einträgst, und überträgt nichts von sich aus. Was Du fragst, entscheidet,
welche Daten an die KI gehen – und damit an deren Anbieter.

## Sicherung & Wiederherstellung

Zwei Wege, die unterschiedliche Zwecke haben:

| | Tools → „Daten exportieren“ | Tools → „Backup erstellen …“ |
|---|---|---|
| Format | JSON, lesbar | komprimiertes Archiv (`.fuhrparkbackup`) |
| Fuhrparkdaten | ja | ja |
| Einstellungen | nur Fensterpositionen | alle, inkl. API-Schlüssel |
| Belegdateien | nein, nur Verweise | ja, vollständig |
| gedacht zum | Weitergeben, Ansehen | Sichern der eigenen Installation |

Beim Backup wird der Zielordner abgefragt; die Datei heißt
`FuhrparkDesktop-Backup_<Datum-Uhrzeit>.fuhrparkbackup`.

Beim Einspielen (`Tools → „Backup einspielen …“`) fragt die App nach einer
Bestätigung – **der gesamte vorhandene Bestand wird ersetzt.** Enthält das
Backup Belege, wird anschließend gefragt, in welchem Ordner sie abgelegt
werden sollen. Der darf ein anderer sein als beim Sichern; die Pfade in der
Datenbank sind relativ und müssen nicht angepasst werden. Belegordner, die
dort liegen und nicht zum Backup gehören, werden entfernt – normale Dateien
und Ordner ohne UUID-Namen bleiben unangetastet.

Nach dem Einspielen die App neu starten, damit alle wiederhergestellten
Einstellungen greifen.

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

### Getrennte Datenbestände

Debug- und Release-Build tragen unterschiedliche Bundle-IDs. Da die App
sandboxed ist, hängt der gesamte Container daran – Datenbank, Einstellungen,
Arbeitsverzeichnis und erteilte Berechtigungen sind damit getrennt, und beide
Ausgaben lassen sich gleichzeitig betreiben:

| | Bundle-ID | Datenbank |
|---|---|---|
| Release | `de.gerdklaus.FuhrparkDesktop` | `~/Library/Containers/de.gerdklaus.FuhrparkDesktop/Data/Library/Application Support/FuhrparkDesktop/` |
| Debug | `de.gerdklaus.FuhrparkDesktop.debug` | `~/Library/Containers/de.gerdklaus.FuhrparkDesktop.debug/Data/…` |

Der Testbau ist am blaugrauen Icon, am Namen „FuhrparkDesktop Debug“ in der
Menüleiste und am Untertitel „Testdaten“ in der Fensterleiste zu erkennen. Sein
MCP-Server trägt sich als `fuhrpark-debug` ein.

Beide Prozesse heißen `FuhrparkDesktop`; zum gezielten Beenden am Pfad
unterscheiden (`pgrep -f "Debug/FuhrparkDesktop.app"`). Gib dem Testbau ein
**eigenes** Arbeitsverzeichnis – zeigen beide auf denselben Ordner, räumt der
Abgleich beim Löschen die Belege des jeweils anderen weg. Die App weist beim
Festlegen darauf hin.

## Projektstruktur

```
Fuhrpark/
  App/           Einstiegspunkt (main.swift), Menüleiste, ContentView
  Models/        Core-Data-Modell (Fuhrpark.xcdatamodeld) + Extensions
  MCP/           MCP-Server: Transport, Protokoll, Werkzeuge, Einrichtung
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

Erzeugt ein installierbares DMG unter `dist/FuhrparkDesktop-<Version>.dmg`
sowie `dist/version.json` – das Manifest für die Update-Prüfung.

Zum Veröffentlichen beides auf den Webspace laden:

| Datei | Ziel |
|---|---|
| `dist/FuhrparkDesktop-<Version>.dmg` | `downloads/` |
| `dist/version.json` | `updates/version.json` |

Vor dem Hochladen im Manifest `notes` aus `VERSION.md` füllen. Ohne das
aktualisierte Manifest erfahren bestehende Installationen nichts von der
neuen Version.

## Kontakt

Solltest Du Fragen, Anregungen etc. haben, dann darfst Du gerne [Kontakt](mailto:nospam@gerd-klaus.de) zu mir aufnehmen. Wenn es meine Zeit zulässt, werde ich gerne weiterhelfen.
