#!/bin/bash
# Wraps the SwiftPM executable into build/Waterline.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-debug}"
version=$(sed -n 's/.*current = "\(.*\)".*/\1/p' Sources/WaterlineKit/Version.swift)
bin=$(xcrun swift build -c "$configuration" --show-bin-path)
app=build/Waterline.app

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/WaterlineApp" "$app/Contents/MacOS/WaterlineApp"
sed "s/__VERSION__/$version/g" Resources/Info.plist > "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - "$app"
echo "$app"
