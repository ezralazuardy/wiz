#!/usr/bin/env bash
set -e

# Clean previous build artifacts
rm -rf dist/*

# Ensure environment file exists (fallback to example)
if [ ! -f .env ]; then
  cp .env.example .env
fi

# Build the executable (named 'Wiz')
swiftc -o dist/Wiz src/*.swift -framework SwiftUI -framework AppKit -framework AVFoundation

# Create the app bundle structure
mkdir -p dist/Wiz.app/Contents/MacOS
mkdir -p dist/Wiz.app/Contents/Resources

# Copy the executable into the app bundle
cp dist/Wiz dist/Wiz.app/Contents/MacOS/

# Clean up the top-level executable after it has been bundled
rm -f dist/Wiz

# Generate .icns icon from the PNG using iconutil
ICON_SRC=src/Assets.xcassets/AppIcon.appiconset/wizmac.png
ICONSET_DIR=dist/icon.iconset
mkdir -p "$ICONSET_DIR"
# Create required icon sizes (both @1x and @2x where applicable)
for SIZE in 16 32 64 128 256 512 1024; do
  sips -z $SIZE $SIZE "$ICON_SRC" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" >/dev/null
  # @2x version (double size)
  DOUBLE=$((SIZE * 2))
  if [ $DOUBLE -le 1024 ]; then
    sips -z $DOUBLE $DOUBLE "$ICON_SRC" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  fi
done
iconutil -c icns "$ICONSET_DIR" -o dist/Wiz.app/Contents/Resources/Wiz.icns
# Clean up temporary iconset folder
rm -rf "$ICONSET_DIR"

# Write Info.plist with network permissions
cat > dist/Wiz.app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Wiz</string>
    <key>CFBundleIdentifier</key><string>org.ezralazuardy.wiz</string>
    <key>CFBundleName</key><string>Wiz</string>
    <key>CFBundleIconFile</key><string>Wiz</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSLocalNetworkUsageDescription</key><string>Wiz needs access to your local network to discover and control your smart devices.</string>
</dict>
</plist>
EOF

# Write entitlements file for sandbox permissions
cat > dist/Wiz.app/Contents/Resources/Wiz.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.network.server</key><true/>
</dict>
</plist>
EOF

echo "Build complete: dist/Wiz.app"