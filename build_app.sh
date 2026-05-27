#!/bin/bash

APP_NAME="AndroidFile"
BUILD_PATH=".build/debug/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# 1. Build
swift build

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

# 2. Create structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# 3. Copy binary
cp "$BUILD_PATH" "$MACOS/"

# 4. Create Info.plist
cat <<EOF > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.androidfile</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Sign
codesign -s - -v -f "$APP_BUNDLE"

echo "Success! $APP_BUNDLE created."
echo "Launch it using: open $APP_BUNDLE"
