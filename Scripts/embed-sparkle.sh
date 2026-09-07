#!/bin/bash
# Embed the reviewed SwiftPM artifact, preserving framework layout and nested entitlements.
set -euo pipefail
app="${1:?application path required}"
artifacts="${2:-.build/artifacts}"
framework="$artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
identity="${WATERLINE_SIGNING_IDENTITY:--}"
codesign --verify --deep --strict "$framework"
mkdir -p "$app/Contents/Frameworks"
ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
cp Resources/Sparkle-LICENSE.txt "$app/Contents/Resources/"
embedded="$app/Contents/Frameworks/Sparkle.framework"
sign_nested() {
    if [[ "$identity" == - ]]; then
        codesign --force --sign - --preserve-metadata=entitlements "$1"
    else
        codesign --force --sign "$identity" --options runtime --timestamp --preserve-metadata=entitlements "$1"
    fi
}
sign_nested "$embedded/Versions/B/Autoupdate"
sign_nested "$embedded/Versions/B/Updater.app"
for service in "$embedded/Versions/B/XPCServices/"*.xpc; do
    sign_nested "$service"
done
sign_nested "$embedded"
codesign --verify --deep --strict "$embedded"
