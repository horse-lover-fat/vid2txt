#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CARGO_TARGET_DIR="$ROOT/target"

APP_NAME="Vid2txt"
CLI_NAME="vid2txt"
VERSION="$(awk -F '"' '/^version/ { print $2; exit }' Cargo.toml)"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
APP="$STAGE/${APP_NAME}.app"
DMG="$DIST/${CLI_NAME}-${VERSION}-macos.dmg"
FEATURES="${VID2TXT_FEATURES:-}"

echo "Building release binary..."
if [[ -n "$FEATURES" ]]; then
  cargo build --release --features "$FEATURES"
else
  cargo build --release
fi

echo "Staging app bundle..."
rm -rf "$DIST"
mkdir -p "$STAGE"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$CARGO_TARGET_DIR/release/$CLI_NAME" "$APP/Contents/Resources/$CLI_NAME"
chmod +x "$APP/Contents/Resources/$CLI_NAME"

cat > "$APP/Contents/MacOS/$CLI_NAME" <<'LAUNCHER'
#!/bin/bash
set -euo pipefail

APP_RESOURCES="$(cd "$(dirname "$0")/../Resources" && pwd)"
BINARY="$APP_RESOURCES/vid2txt"

if [[ -t 1 ]]; then
  exec "$BINARY" --help
fi

escaped_binary="${BINARY//\\/\\\\}"
escaped_binary="${escaped_binary//\"/\\\"}"

/usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "exec \\"${escaped_binary}\\" --help"
end tell
APPLESCRIPT
LAUNCHER
chmod +x "$APP/Contents/MacOS/$CLI_NAME"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$CLI_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>ca.local.vid2txt</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

cp "$CARGO_TARGET_DIR/release/$CLI_NAME" "$STAGE/$CLI_NAME"
chmod +x "$STAGE/$CLI_NAME"

cp "$ROOT/scripts/path-setup.sh" "$STAGE/path-setup.sh"
cp "$ROOT/scripts/install-from-bundle.sh" "$STAGE/install-from-bundle.sh"
chmod +x "$STAGE/install-from-bundle.sh"

cat > "$STAGE/Install CLI Tool.command" <<'INSTALLER'
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
export VID2TXT_SOURCE="$DIR/vid2txt"

"$DIR/install-from-bundle.sh"

echo
read -r -p "Press Enter to close..."
INSTALLER
chmod +x "$STAGE/Install CLI Tool.command"

ln -sf /Applications "$STAGE/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

echo "Done: $DMG"
ls -lh "$DMG"
echo
echo "DMG includes:"
echo "  - ${APP_NAME}.app (Finder launch, shows usage)"
echo "  - vid2txt (standalone binary)"
echo "  - Install CLI Tool.command (installs to ~/.local/bin and updates PATH)"
