# Versionshistorie

Alle nennenswerten Änderungen an FuhrparkDesktop, gruppiert nach Release.
Die Versionen sind als Git-Tags (`v1.1` … `v1.5`) markiert.

## [v1.5](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.5) – 2026-08-06

### Neu
- **KI-Zugriff (MCP)**: Die Fuhrparkdaten lassen sich einer KI wie Claude über
  das Model Context Protocol zum Lesen bereitstellen. Dasselbe App-Binary läuft
  dafür wahlweise als GUI oder – mit `--mcp-stdio` gestartet – als MCP-Server.
  Neun ausschließlich lesende Werkzeuge: Flottenübersicht, Fahrzeugdetails,
  Listen für Betankungen, Ausgaben, Erinnerungen und Belege, Kostenauswertung,
  Volltextsuche und Diagnose.
- Neuer Bereich **„KI-Zugriff"** in der Seitenleiste mit fertigen
  Konfigurationsangaben für Claude Desktop und Claude Code zum Kopieren sowie
  einem Selbsttest, der die Verbindung prüft.

### Geändert
- Der Programmeinstieg wandert von `@main` nach `main.swift`, damit die Weiche
  zwischen GUI- und Serverbetrieb vor der AppKit-Initialisierung greift.

### Hinweise zur Umsetzung
- Der Server liest **direkt aus der Datenbank der App** – ohne Kopie, ohne
  Zwischendatei und ohne Zwischenspeicher, der veralten könnte. Verworfen wurde
  die Alternative, eine JSON-Momentaufnahme in einen Nutzerordner zu schreiben:
  Sie hätte ein unverschlüsseltes Duplikat aller Daten außerhalb der Sandbox
  bedeutet und wäre nie ganz aktuell gewesen.
- Der Protokollstrom ist strukturell abgesichert: Beim Start wird der echte
  stdout dupliziert und Deskriptor 1 auf stderr umgebogen. Fremdausgaben können
  die Rahmung der Nachrichten damit nicht mehr zerstören.

## [v1.4](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.4) – 2026-08-06

### Geändert
- **Dokumente**: Dateien werden beim Hinzufügen jetzt in ein
  konfigurierbares Arbeitsverzeichnis kopiert statt nur per Verknüpfung auf
  den Originalspeicherort referenziert – Dokumente bleiben dadurch auch
  auffindbar, wenn sich der Ablageort der Originaldatei ändert. Der
  Leer-Zustand weist darauf hin, wenn zuerst ein Arbeitsverzeichnis
  eingerichtet werden muss.
- Der Ordner-Auswahldialog für das Arbeitsverzeichnis lässt sich jetzt frei
  auf dem Bildschirm verschieben.
- Sidebar: Sektion "Allgemein" ist jetzt ebenfalls ein-/ausklappbar.

## [v1.3](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.3) – 2026-07-27

### Neu
- **Erinnerungen**: neuer Bereich für wiederkehrende oder einmalige Termine
  (z. B. TÜV, Versicherung, Steuer) pro Fahrzeug, mit wählbarer Vorlaufzeit
  und Fälligkeits-Badge in der Sidebar.

### Geändert
- Sidebar: "Spritpreise" hinter "Erinnerungen" einsortiert.

## [v1.2](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.2) – 2026-07-22

### Neu
- **Dokumente**: neuer Bereich für Belege/Rechnungen, die einer Ausgabe und
  einem Fahrzeug zugeordnet werden können, inkl. Export/Import und Anzeige
  per Büroklammer-Symbol bei der jeweiligen Ausgabe.
- **Fahrzeug bearbeiten**: bestehende Fahrzeuge lassen sich nachträglich
  ändern; Stilllegen/Bearbeiten/Löschen sind in einem gemeinsamen
  Aktionsmenü gebündelt.
- Sidebar: eigene, nach Kennzeichen sortierte Sektion "Stillgelegte
  Fahrzeuge".
- Statistik: neue Karte "Gefahrene km pro Jahr" (interpoliert, mit
  Verlaufsgrafik und berechnetem Tachostand).
- Statistik: "Gesamtkosten pro Kategorie" um Prozentanteil und
  Donut-Chart-Button ergänzt.
- Statistik: "Kosten pro Jahr" um Balkendiagramm-Button ergänzt.
- Statistik-Karten in der Fahrzeug-Detailansicht lassen sich einzeln
  ein-/ausblenden.
- Kennzeichen-Duplikatsprüfung beim Anlegen/Bearbeiten eines Fahrzeugs.
- Spritpreise: Auswahl der Kraftstoffsorten-Checkboxen wird jetzt
  gespeichert.

### Geändert
- Stilllegen eines Fahrzeugs ist jetzt endgültig (keine Reaktivierung mehr);
  sonstige Ausgaben lassen sich danach weiterhin erfassen.
- README um Badges, Lizenzhinweis (MIT) und Kontakt ergänzt.

### Behoben
- ⌘W schloss immer das Hauptfenster statt des tatsächlich aktiven Fensters.
- Leicht inkonsistente Glass-Hintergrundfarbe in Karten, Statistik,
  Formularen und Listenfenstern (ab der 6. Karte sichtbar).

## [v1.1](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.1) – 2026-07-16

Erste veröffentlichte Version.

### Funktionen
- Fahrzeugverwaltung (Kennzeichen, Hersteller, Modell, Tachostand),
  Fahrzeug stilllegen und wieder in Betrieb nehmen.
- Betankungen und sonstige Ausgaben in eigenen Fenstern statt Inline-Listen;
  sonstige Ausgaben können auch Einnahmen erfassen und verrechnen.
- Benutzerdefinierte Ausgaben-Kategorien pro Fahrzeug (mehrere Kategorien
  je Ausgabe, Filterung nach Kategorie in der Ausgabenliste).
- Statistik: Betankungen, Spritpreis, Verbrauch, Gesamtkosten pro Kategorie,
  Kosten pro Jahr (alle Fahrzeuge) – jeweils mit Verlaufsdiagramm.
- Spritpreise: Umkreissuche über die Tankerkönig-API mit Abklingzeit/
  Countdown und automatischer Aktualisierung.
- Empfänger- und Tankstelle-Felder mit Autovervollständigung.
- Sidebar mit Sektionen, Statistik-Übersicht, Sortierung nach letzter
  Änderung, Anfangs-/Höchststand je Fahrzeug.
- JSON-Export/-Import aller Daten über das Tools-Menü.
- "Alle Daten löschen" mit Sicherheitsabfrage.
- Fenstergröße und -position werden gespeichert und wiederhergestellt.
- App-Icon sowie deutsch/englisch lokalisierte Systemmenüs.
- Release-Build-Pipeline für die DMG-Datei.
