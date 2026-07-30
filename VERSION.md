# Versionshistorie

Alle nennenswerten Änderungen an FuhrparkDesktop, gruppiert nach Release.
Die Versionen sind als Git-Tags (`v1.1`, `v1.2`, `v1.3`) markiert.

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
