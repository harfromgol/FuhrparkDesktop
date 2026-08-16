#!/bin/bash
# Baut FuhrparkDesktop im Release-Modus und packt ein fertiges,
# doppelklickbares Installations-DMG (App-Icon links, Programme-Symlink
# rechts, Pfeil-Hintergrundbild dazwischen).
#
# Aufruf (vom Repo-Wurzelverzeichnis):
#   Scripts/build_dmg.sh
#
# Ergebnis: dist/FuhrparkDesktop-<Version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="FuhrparkDesktop"
SCHEME="FuhrparkDesktop"
DIST_DIR="dist"
STAGING="$DIST_DIR/staging"
DERIVED_DATA="$DIST_DIR/DerivedData"

rm -rf "$STAGING" "$DERIVED_DATA"
mkdir -p "$STAGING"

echo "==> Projekt generieren"
xcodegen generate

echo "==> Release-Build"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED_DATA" build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

# Debug- und Release-Build tragen verschiedene Bundle-IDs (siehe project.yml).
# Käme versehentlich die Debug-ID ins DMG, legte die App beim Nutzer einen
# zweiten, leeren Sandbox-Container an, statt seine vorhandenen Daten zu
# öffnen – ein Fehler, der wie Datenverlust aussieht. Deshalb hart prüfen.
ERWARTETE_ID="de.gerdklaus.FuhrparkDesktop"
GEBAUTE_ID=$(plutil -extract CFBundleIdentifier raw "$BUILT_APP/Contents/Info.plist")
if [ "$GEBAUTE_ID" != "$ERWARTETE_ID" ]; then
  echo "ABBRUCH: gebaute Bundle-ID ist '$GEBAUTE_ID', erwartet '$ERWARTETE_ID'." >&2
  exit 1
fi

VERSION=$(plutil -extract CFBundleShortVersionString raw "$BUILT_APP/Contents/Info.plist")
DMG_FINAL="$DIST_DIR/$APP_NAME-$VERSION.dmg"
DMG_TMP="$DIST_DIR/pack.temp.dmg"
VOL_NAME="$APP_NAME"

echo "==> Version $VERSION erkannt"

echo "==> Hintergrundbild erzeugen"
swift Scripts/generate_dmg_background.swift "$DIST_DIR"

echo "==> Staging-Ordner befüllen"
cp -R "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
mkdir "$STAGING/.background"
cp "$DIST_DIR/background.png" "$DIST_DIR/background@2x.png" "$STAGING/.background/"

rm -f "$DMG_TMP" "$DMG_FINAL"
SIZE_MB=$(( $(du -sm "$STAGING" | cut -f1) + 20 ))

echo "==> Schreibbares DMG erzeugen"
hdiutil create -srcfolder "$STAGING" -volname "$VOL_NAME" -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${SIZE_MB}m" "$DMG_TMP"

MOUNT_DIR=$(hdiutil attach -readwrite -noverify -nobrowse "$DMG_TMP" \
  | grep -E '^/dev/' | grep 'Volumes' | awk -F'\t' '{print $NF}')

echo "==> Finder-Fensterlayout setzen ($MOUNT_DIR)"
osascript <<OSA
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 1020, 520}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {165, 205}
    set position of item "Applications" of container window to {455, 205}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
OSA

chmod -Rf go-w "$MOUNT_DIR" &> /dev/null || true
sync
hdiutil detach "$MOUNT_DIR"

echo "==> Komprimiertes DMG erzeugen"
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TMP"
rm -rf "$STAGING" "$DERIVED_DATA"

# Manifest für die Update-Prüfung (siehe UpdateCheckService). Wird aus
# derselben Version erzeugt wie das DMG – von Hand gepflegt liefe es sonst
# irgendwann der tatsächlichen Version hinterher, und die App meldete
# entweder nichts oder ein Update, das es nicht gibt. "notes" und
# "publishedAt" müssen noch gefüllt werden, danach beides zusammen auf den
# Webspace laden.
MANIFEST="$DIST_DIR/version.json"
cat > "$MANIFEST" <<EOF
{
  "version": "$VERSION",
  "publishedAt": "$(date +%Y-%m-%d)",
  "minimumSystemVersion": "26.0",
  "downloadPageURL": "https://fuhrpark-macos.gerd-klaus.de/#download",
  "notes": [
    "TODO: Stichpunkte aus VERSION.md eintragen"
  ]
}
EOF

echo "==> Fertig: $DMG_FINAL"
echo "==> Manifest: $MANIFEST (notes ergänzen, dann nach updates/version.json hochladen)"
