#!/bin/zsh
# Compila y empaqueta Still.app (sin Xcode).
#   ./build.sh            -> build/Still.app
#   ./build.sh --install  -> además la instala en /Applications y la abre
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swift >/dev/null; then
    echo "Falta Swift. Instala las Command Line Tools: xcode-select --install" >&2
    exit 1
fi
if ! command -v gh >/dev/null; then
    echo "Aviso: no encuentro gh. Instálalo (brew install gh) y ejecuta gh auth login." >&2
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Still"

APP="build/Still.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Still"
mkdir -p "$APP/Contents/Resources/Fonts"
cp Fonts/*.ttf Fonts/OFL-*.txt "$APP/Contents/Resources/Fonts/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>still.</string>
    <key>CFBundleDisplayName</key><string>still.</string>
    <key>CFBundleIdentifier</key><string>dev.still.app</string>
    <key>CFBundleExecutable</key><string>Still</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>ATSApplicationFontsPath</key><string>Fonts</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.3.0</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Listo: $APP"

if [[ "${1:-}" == "--install" ]]; then
    DEST="/Applications"
    [[ -w "$DEST" ]] || { echo "No puedo escribir en $DEST. Prueba con: sudo ./build.sh --install" >&2; exit 1; }
    pkill -x Still 2>/dev/null || true
    pkill -x PipelinesDrop 2>/dev/null || true
    # Nombre anterior
    rm -rf "$HOME/Applications/PipelinesDrop.app" "$DEST/PipelinesDrop.app"
    rm -rf "$DEST/Still.app"
    cp -R "$APP" "$DEST/"
    open "$DEST/Still.app"
    echo "Instalada en $DEST/Still.app"
fi
