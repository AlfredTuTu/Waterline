#!/bin/bash
# Wraps the SwiftPM executable; Developer ID signing is opt-in through an explicit identity.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-debug}"
signing_identity="${WATERLINE_SIGNING_IDENTITY:--}"
if [[ "$signing_identity" != "-" && "$configuration" != "release" ]]; then
    echo "Developer ID signing requires CONFIGURATION=release." >&2
    exit 64
fi
version=$(sed -n 's/.*current = "\(.*\)".*/\1/p' Sources/WaterlineKit/Version.swift)
bin=$(xcrun swift build -c "$configuration" --show-bin-path)
app=build/Waterline.app

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/WaterlineApp" "$app/Contents/MacOS/WaterlineApp"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$app/Contents/Resources/"
cp Resources/ProviderLogos/*.png "$app/Contents/Resources/"
cp Resources/ProviderLogos/LICENSE.txt "$app/Contents/Resources/ProviderLogos-LICENSE.txt"
bash Scripts/build-icon.sh "$app/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$version/g" Resources/Info.plist > "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - "$app"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$app"
fi
codesign --verify --strict "$app"
echo "$app"
