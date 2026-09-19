#!/bin/bash
# Builds build/Accordion.app. Pass --install to also copy it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Accordion.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 \
    Sources/*.swift -o "$APP/Contents/MacOS/Accordion"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# A fixed designated requirement keeps macOS permissions (Screen Recording) across rebuilds.
codesign --force --sign - -r='designated => identifier "com.braydonglass.accordion"' "$APP"
echo "built $APP"

if [ "${1:-}" = "--install" ]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/Accordion.app
    cp -R "$APP" ~/Applications/Accordion.app
    echo "installed ~/Applications/Accordion.app"
fi
