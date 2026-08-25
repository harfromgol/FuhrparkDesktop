# Versionshistorie

Alle nennenswerten Änderungen an FuhrparkDesktop, gruppiert nach Release.
Die Versionen sind als Git-Tags (`v1.1` … `v1.9`) markiert.

## [v1.9](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.9) – 2026-08-25

### Neu
- **Fahrzeugbild**: Fahrzeuge können jetzt ein Foto erhalten (Auswahl aus
  Datei oder Fotos-App), mit rundem Zuschnitt-Editor (Drag-/Zoom-Geste plus
  Slider, Vorschau entspricht exakt dem Export). Das Bild wird beim
  Aufräumen des Arbeitsverzeichnisses, in Backup/Restore und im
  JSON-Export/Import korrekt mitgeführt.
- **Fahrzeugbild-Anordnung wählbar**: Per Rechtsklick-Kontextmenü auf dem
  Bild in der Fahrzeug-Detailansicht lässt sich wählen, ob es wie bisher
  klein seitlich vor dem Kennzeichen sitzt oder groß und zentriert über der
  ganzen Karte, dort zusätzlich in einer Größenstufe 1–5. Die Wahl übersteht
  einen Neustart, Standard bleibt die bisherige seitliche Anordnung.
- **Sortierbare Tabellen**: Die drei Statistiktabellen der
  Fahrzeug-Detailansicht (Kosten pro Kategorie, Kosten pro Jahr, gefahrene
  km pro Jahr) sowie „Kosten je Fahrzeug" und „Kosten pro Jahr" in der
  Flotten-Statistik lassen sich jetzt per Klick auf die Kopfzeile
  spaltenweise auf- oder absteigend sortieren. Ein Chevron markiert die
  aktive Spalte; die Wahl gilt global je Tabellentyp und übersteht einen
  Neustart.
- **Fahrzeugliste per Drag & Drop sortierbar**: Die Seitenleiste ordnet
  Fahrzeuge nicht mehr automatisch nach letzter Änderung (neue Betankung
  oder Ausgabe schob sie bisher nach oben). Neue Fahrzeuge erscheinen ganz
  oben, ansonsten legt die Reihenfolge jetzt der Nutzer per Drag & Drop
  selbst fest und sie bleibt stabil, bis er sie erneut verschiebt.

### Geändert
- „Kosten je Fahrzeug" in der Statistik sortiert nicht mehr zusätzlich
  stillgelegte Fahrzeuge ans Ende, sondern durchgehend nach der gewählten
  Spalte – die Tabelle zeigt den Stillgelegt-Status ohnehin nicht an.
- Das Büroklammer-Symbol in der Dokumentenliste steht jetzt nur noch vor
  dem Dateinamen statt über die ganze Zeile.

### Behoben
- Die über das Werkzeuge-Menü geöffneten Panels (Backup erstellen/einspielen,
  JSON exportieren/importieren) erschienen manchmal gar nicht und
  brauchten mehrere Klicks – ein Timing-Problem beim Öffnen direkt aus der
  Menü-Aktion heraus.
- Der Klick aufs Fahrzeugbild-Icon prüft jetzt vorab, ob ein
  Arbeitsverzeichnis konfiguriert ist, statt erst nach dem Zuschneiden mit
  einer Fehlermeldung zu scheitern.
- „Alle Daten löschen" setzt jetzt auch die Zuordnung des
  Arbeitsverzeichnisses zurück, nicht nur die Fuhrparkdaten.

## [v1.8.1](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.8.1) – 2026-08-20

### Geändert
- **Dokumente-Filter überarbeitet**: Die bisherigen Filterkarten sind einem
  Filter-Symbol samt Einstellungsfenster gewichen, ergänzt um Filter nach
  Fahrzeugstatus (Alle/Aktiv/Stillgelegt) und nach Zeitraum. Fahrzeug und
  Kategorie werden über Dropdown-Boxen statt Chips gewählt, damit sich das
  Fenster nicht mehr verschiebt, wenn sich die Anzahl der Einträge ändert.
  Die Filter verunden sich und kaskadieren: Fahrzeugstatus schränkt die
  wählbaren Fahrzeuge ein, beide zusammen die wählbaren Kategorien.
- **Tools-Menü aufgeräumt**: „Daten exportieren“/„Daten importieren“ heißen
  jetzt „JSON exportieren“/„JSON importieren“ und liegen als Untermenü
  „Fuhrpark Web“ hinter Backup/Restore statt davor.
- **Diagramme reagieren auf die Maus**: Beim Überfahren mit dem Zeiger wird
  in allen Statistik-Diagrammen (Verbrauch- und Preis-Verlauf,
  Kategorie-Kreisdiagramm, Kosten und gefahrene Kilometer pro Jahr) die
  jeweils getroffene Stelle leicht hervorgehoben und der genaue Wert als
  Tooltip an der Mausposition eingeblendet.

## [v1.8](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.8) – 2026-08-16

### Neu
- **Vollständige Sicherung und Wiederherstellung**: „Backup erstellen …“ im
  Tools-Menü schreibt Fuhrparkdaten, **alle** Einstellungen und die
  Belegdateien in ein einzelnes komprimiertes Archiv
  (`.fuhrparkbackup`); der Ablageort wird vorher abgefragt. „Backup
  einspielen …“ ersetzt den gesamten Bestand nach einer Sicherheitsabfrage.
  Enthält das Archiv Belege, wird gefragt, wo sie abgelegt werden sollen –
  das darf ein anderer Ordner sein als beim Sichern. Abgrenzung zum
  bestehenden JSON-Export: Der bleibt das teilbare, lesbare Format ohne
  Belegdateien und ohne API-Schlüssel; das Backup ist die private
  Komplettkopie derselben Installation und enthält beides.
- **Hinweis auf neue Versionen**: Die App kann beim Start höchstens einmal
  täglich nachsehen, ob auf der Produktseite eine neuere Version steht, und
  weist mit einem Kurz-Changelog darauf hin. Beim ersten Start wird die
  Erlaubnis dafür ausdrücklich erfragt; abgerufen wird eine statische Datei
  **ohne** jeden Parameter, die verwendete Version geht nicht mit.
  Ein- und ausschaltbar über „Automatisch nach Updates suchen“ im
  App-Menü, dazu „Nach Updates suchen …“ für die Prüfung von Hand.
  Heruntergeladen oder installiert wird nichts von selbst.
- **PDF-Export für die Betankungsliste** und **für die Ausgabenliste**, je
  über ein neues Menü in der Fenster-Titelleiste. Beide Berichte sind als
  durchgehende Tabelle im Stil einer Tabellenkalkulation gesetzt, mit
  abwechselnd hinterlegten Zeilen; der Seitenumbruch liegt immer auf einer
  Zeilengrenze.
- **Preis direkt in der Menüleiste**: Ist genau eine Tankstelle/Sorte
  angepinnt, steht der Preis neben dem Zapfsäulen-Symbol statt erst im
  Popover.

### Geändert
- Der Menüpunkt „PDF“ heißt in Statistik und Fahrzeugdetails jetzt
  einheitlich „PDF-Export“.
- Der Blätter-Knopf unten in den Listen heißt „Weiter ›“ statt „› Weiter“.
- `Scripts/build_dmg.sh` erzeugt neben dem DMG jetzt auch
  `dist/version.json` – das Manifest für die Update-Prüfung – aus derselben
  Versionsnummer wie das DMG.

## [v1.7](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.7) – 2026-08-14

### Neu
- **Spritpreise in der Menüleiste**: angepinnte Tankstellen/Sorten lassen
  sich gezielt und unabhängig von der Umkreissuche abfragen. Auswahl,
  Aktualisierungsintervall und zuletzt geladene Preise überstehen einen
  Neustart der App.
- **Betankungsliste**: Jahresfilter (nur Jahre mit Betankungen) und
  einstellbare Paginierung (5–15 Einträge je Seite, mit Vor/Zurück und
  Seitenanzeige).
- **Ausgabenliste**: dieselbe Paginierung jetzt auch hier, über eine mit der
  Betankungsliste gemeinsam genutzte Komponente.
- **PDF-Export für Fahrzeugberichte**: In der Fahrzeug-Detailansicht erzeugt
  „PDF" im Aktionsmenü ein mehrseitiges PDF mit genau den Kennzahlen-Karten,
  die gerade eingeblendet sind, und öffnet es direkt in Vorschau.app. Jede
  Seite trägt einheitlichen Kopf-/Fußrand und eine „Seite X von Y"-Fußzeile;
  die Paginierung bricht nie mitten in einer Karte oder Tabellenzeile um –
  auch nicht, wenn eine Tabellen-Karte durch viele Jahre/Kategorien selbst
  höher als eine Seite wird.
- **PDF-Export für die Statistikseite**: dieselbe Berichts-Infrastruktur,
  ausgelöst über ein neues Menü neben der Überschrift „Übersicht", mit den
  Karten Übersicht, Kosten je Fahrzeug und Kosten pro Jahr.
- **Sidebar-Menüpunkte konfigurierbar**: Dokumente, Erinnerungen, Spritpreise
  und KI-Zugriff lassen sich einzeln aus der Seitenleiste ausblenden, über
  ein neues Konfigurationssymbol neben „Neues Fahrzeug".

### Geändert
- Sidebar: Symbole der Allgemein-Menüpunkte in Systemblau.
- Fahrzeugdetails: die Karten „Betankungen – Statistik" und „Sonstige
  Ausgaben – Statistik" zeigen ihre Kennzahlen jetzt ohne eigene
  Kartenüberschrift, direkt unter der Abschnittsüberschrift.
- Der PDF-Export der Fahrzeugdetails liegt jetzt als Eintrag „PDF" im
  bestehenden Aktionsmenü statt in einem eigenen Symbol daneben.

### Behoben
- Export-, Import- und Dokument-Auswahldialoge liefen über
  `.fileExporter`/`.fileImporter` und ließen sich dadurch nicht frei auf
  dem Bildschirm verschieben.

## [v1.6](https://github.com/harfromgol/FuhrparkDesktop/releases/tag/v1.6) – 2026-08-07

### Neu
- **Ein Beleg kann mehrere sonstige Ausgaben belegen.** Wird eine Rechnung auf
  zwei Ausgaben aufgeteilt, hängt sie jetzt an beiden – als **eine** Zeile in
  der Dokumentenliste und mit **einer** Dateikopie. Der Zuordnungsdialog ist
  dafür eine Mehrfachauswahl geworden; die Zuordnung lässt sich über das
  Kontextmenü einer Belegzeile auch nachträglich ändern.
- Beim Festlegen des Arbeitsverzeichnisses wird gemeldet, wenn dort
  Belegordner liegen, die nicht zum geöffneten Datenbestand gehören – bevor
  der nächste Löschvorgang sie entfernt.

### Behoben
- **Import zerstörte die Belegdateien**: Der Import löschte erst das
  Arbeitsverzeichnis und legte danach Einträge an, die genau auf die gerade
  gelöschten Dateien zeigten. Ein Reimport des eigenen Exports zeigte
  anschließend überall „Datei nicht gefunden“.
- **Verwaiste Dateien**: Das Löschen einer Ausgabe oder eines Fahrzeugs
  entfernte die Einträge, ließ die Dateien aber liegen.
- **Nachträgliches Zuordnen öffnete ein leeres Fenster**: Aus einem
  Kontextmenü heraus präsentiert SwiftUI ein Sheet noch mit dem Stand vor der
  Zustandsänderung; der Beleg fehlte dadurch im Inhalt.
- **Löschen eines Belegs konnte das gesamte Arbeitsverzeichnis leeren**: Der
  Ablageordner wurde aus dem gespeicherten Pfad abgeleitet. Enthielt der
  keinen Schrägstrich – über eine importierte JSON-Datei erreichbar –, zeigte
  das Ergebnis auf das Arbeitsverzeichnis selbst.

### Geändert
- **Debug- und Release-Build arbeiten auf getrennten Datenbeständen.** Beide
  tragen eigene Bundle-IDs und damit eigene Sandbox-Container: eigene
  Datenbank, eigene Einstellungen, eigenes Arbeitsverzeichnis. Sie lassen sich
  gleichzeitig betreiben und sind am Icon, am Namen in der Menüleiste und am
  Untertitel „Testdaten“ in der Fensterleiste zu unterscheiden. Für installierte
  Fassungen ändert sich nichts – die Bundle-ID der Release-Ausgabe bleibt
  gleich.
- Der MCP-Server des Testbaus meldet und registriert sich als
  `fuhrpark-debug` und überschreibt die Einrichtung der produktiven App damit
  nicht. `list_documents` liefert statt `ausgabe` nun `ausgaben` als Liste,
  dazu `anzahlAusgaben`.
- **Exportschema 6 → 7.** Das Format bleibt verschachtelt: Ein geteilter Beleg
  erscheint bei jeder seiner Ausgaben mit derselben `id` und wird beim Import
  wieder zu einem Eintrag zusammengeführt. **FuhrparkWeb bleibt dadurch ohne
  Änderung kompatibel.**

### Hinweise zur Umsetzung
- Erstmals findet beim Start eine echte **Core-Data-Modellmigration** statt
  (Modellversion 2). Bisherige Modelländerungen berührten den Versions-Hash
  nicht – Optionalität geht dort nicht ein, die Kardinalität einer Beziehung
  sehr wohl. Die alte Version bleibt deshalb unverändert als Quellmodell
  liegen.
- Beim Entwurf zeigte ein Testlauf auf einer Store-Kopie, dass die abgeleitete
  Migration die Verknüpfung **stillschweigend fallen ließ**, wenn die
  Beziehung gleichzeitig umbenannt und auf „zu vielen“ umgestellt wird. Die
  Beziehung heißt deshalb weiterhin `expense`; geändert wurde nur die
  Kardinalität.
- Scheitert das Öffnen der Datenbank, stürzt die App nicht mehr ab, sondern
  meldet den Fehler. Der MCP-Server migriert grundsätzlich nicht: Eine
  Migration gehört in die sichtbare App, nicht in einen Prozess ohne Fenster.
- Alle vier Löschpfade stellen jetzt dieselbe Invariante wieder her – *das
  Arbeitsverzeichnis enthält genau die Ordner, die die Datenbank kennt*.
  Derselbe Mengenvergleich speist auch den Hinweis beim Verzeichniswechsel,
  damit Anzeige und Löschung nicht auseinanderlaufen können.

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
