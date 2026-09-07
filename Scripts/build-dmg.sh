#!/bin/bash
# Local development image only; public distribution still requires Developer ID and notarization.
set -euo pipefail
cd "$(dirname "$0")/.."

app=build/Waterline.app
test -x "$app/Contents/MacOS/WaterlineApp"
codesign --verify --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(lipo -archs "$app/Contents/MacOS/WaterlineApp" | tr ' ' '-')
image="build/Waterline-$version-$architecture-development.dmg"
staging=$(mktemp -d "${TMPDIR:-/tmp}/waterline-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT

ditto "$app" "$staging/Waterline.app"
ln -s /Applications "$staging/Applications"
cp Resources/DevelopmentInstall.txt "$staging/Read Me.txt"
hdiutil create -ov -format UDZO -volname "Waterline Development" -srcfolder "$staging" "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$image.sha256"
echo "$image"
