## Projekt
- Programmiersprache Swift und SwiftUI

## git
- auf einem Feature-Branch: Commits ohne Nachfrage
- auf main: vor jedem Commit nachfragen ob committet werden soll
- nach einem Merge nach main: Build erstellen und die Debug-App automatisch neu starten, ohne zu fragen

## claude code
- im chat fenster immer deutsch als sprache verwenden

## Release
- Bei jedem neuen Versions-Build (VERSION.md, project.yml, Scripts/build_dmg.sh)
  automatisch auch die Produktwebseite unter
  `/Users/gerd/Projekte/Website/FuhrparkDesktopMacOS` aktualisieren, ohne
  extra danach gefragt zu werden:
  - `downloads/`: altes DMG entfernen, neues hineinkopieren
  - `updates/version.json`: 1:1 aus `dist/version.json` dieses Repos übernehmen
  - `index.html`: Versionsnummer und Downloadgröße an allen Stellen
    nachziehen (Hero-Eyebrow, Hero-Lead, Hero-Meta-Zeile, Download-Sektion –
    die Hero-Meta-Zeile mit der Dateigröße wird leicht übersehen); bei einem
    eigenständigen neuen Kern-Feature zusätzlich eine neue Funktions-Kachel
    ergänzen
  - Committen und per `./deploy.sh` hochladen (Freigabe für Uploads dieser
    einen Seite liegt bereits vor, keine Rückfrage nötig)
