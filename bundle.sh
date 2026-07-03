#!/bin/bash
# Build a minimal .app bundle around the SPM binary (no signing/notarization).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="touchmeplease.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/touchmeplease "$APP/Contents/MacOS/touchmeplease"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>touchmeplease</string>
    <key>CFBundleDisplayName</key>     <string>touchmeplease</string>
    <key>CFBundleIdentifier</key>      <string>com.amiruladli.touchmeplease</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>touchmeplease</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "Built $APP"
