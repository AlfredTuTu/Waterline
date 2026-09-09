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
version=$(sed -n 's/.*current = "\(.*\)".*/\1/p' app/Sources/WaterlineKit/Version.swift)
bin=$(xcrun swift build --package-path app --scratch-path .build -c "$configuration" --show-bin-path)
app=build/Waterline.app

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/WaterlineApp" "$app/Contents/MacOS/WaterlineApp"
cp "$bin/waterline" "$app/Contents/MacOS/waterline"
cp -R app/Resources/en.lproj app/Resources/zh-Hans.lproj "$app/Contents/Resources/"
cp app/Resources/ProviderLogos/*.png "$app/Contents/Resources/"
cp app/Resources/ProviderLogos/LICENSE.txt "$app/Contents/Resources/ProviderLogos-LICENSE.txt"
bash tools/build-icon.sh "$app/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$version/g" app/Resources/Info.plist > "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
sign_code() {
    if [[ "$signing_identity" == "-" ]]; then
        codesign --force --sign - "$1"
    else
        codesign --force --options runtime --timestamp --sign "$signing_identity" "$1"
    fi
}
bash tools/embed-sparkle.sh "$app"
sign_code "$app/Contents/MacOS/waterline"
sign_code "$app"
codesign --verify --deep --strict "$app"
echo "$app"
