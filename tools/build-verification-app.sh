#!/bin/bash
# Separate test-only application. Production builds never define WATERLINE_VERIFICATION.
set -euo pipefail
cd "$(dirname "$0")/.."

xcrun swift build --package-path app -c release --scratch-path .build/verification --product WaterlineApp -Xswiftc -DWATERLINE_VERIFICATION
bin=$(xcrun swift build --package-path app -c release --scratch-path .build/verification --show-bin-path)
app=build/WaterlineVerification.app
version=$(sed -n 's/.*current = "\(.*\)".*/\1/p' app/Sources/WaterlineKit/Version.swift)
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/WaterlineApp" "$app/Contents/MacOS/WaterlineApp"
cp -R app/Resources/en.lproj app/Resources/zh-Hans.lproj "$app/Contents/Resources/"
cp app/Resources/ProviderLogos/*.png "$app/Contents/Resources/"
cp app/Resources/ProviderLogos/LICENSE.txt "$app/Contents/Resources/ProviderLogos-LICENSE.txt"
bash tools/build-icon.sh "$app/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$version/g" app/Resources/Info.plist > "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.github.alfredtutu.waterline.verification' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName WaterlineVerification' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Waterline Verification' "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
WATERLINE_SIGNING_IDENTITY=- bash tools/embed-sparkle.sh "$app" .build/verification/artifacts
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "$app"
