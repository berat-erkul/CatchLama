#!/bin/bash
# Release build → CatchLama.app → /Applications. Çalışan eski sürümü kapatıp yenisini açar.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/CatchLama.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CatchLama "$APP/Contents/MacOS/"
cp Resources/* "$APP/Contents/Resources/"  # AppIcon.icns + menü çubuğu ikonları
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.beraterkul.catchlama</string>
    <key>CFBundleName</key><string>CatchLama</string>
    <key>CFBundleExecutable</key><string>CatchLama</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force -s - "$APP"

pkill -x CatchLama || true
rm -rf /Applications/CatchLama.app
cp -R "$APP" /Applications/
open /Applications/CatchLama.app
echo "✓ /Applications/CatchLama.app çalışıyor (menü çubuğunda llama ikonu)"
