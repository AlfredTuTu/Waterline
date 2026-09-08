#!/bin/bash
# Package a locally signed image; the release mode requires explicit unnotarized-distribution validation.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-development}"
if [[ "$mode" != development && "$mode" != --adhoc-release ]]; then
    echo "usage: build-dmg.sh [--adhoc-release]" >&2
    exit 64
fi
app=build/Waterline.app
test -x "$app/Contents/MacOS/WaterlineApp"
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(lipo -archs "$app/Contents/MacOS/WaterlineApp" | tr ' ' '-')
if [[ "$mode" == --adhoc-release ]]; then
    bash Scripts/check-distribution.sh "$app" --adhoc-release
    image="build/Waterline-$version-$architecture-unnotarized.dmg"
    volume="Waterline $version"
    instructions=Resources/Install.txt
else
    image="build/Waterline-$version-$architecture-development.dmg"
    volume="Waterline Development"
    instructions=Resources/DevelopmentInstall.txt
fi
staging=$(mktemp -d "${TMPDIR:-/tmp}/waterline-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT

ditto "$app" "$staging/Waterline.app"
ln -s /Applications "$staging/Applications"
cp "$instructions" "$staging/Read Me.txt"
hdiutil create -ov -format UDZO -volname "$volume" -srcfolder "$staging" "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$image.sha256"
echo "$image"
