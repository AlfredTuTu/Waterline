#!/bin/bash
# Read-only artifact checks. Passing does not replace provider, UI or clean-install acceptance.
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-build/Waterline.app}"
mode="${2:-complete}"
if [[ "$mode" != complete && "$mode" != --pre-notarization ]]; then
    echo "usage: check-distribution.sh [app] [--pre-notarization]" >&2
    exit 64
fi
status=0
icon_check=$(mktemp -d "${TMPDIR:-/tmp}/waterline-icon-check.XXXXXX")
trap 'rm -rf "$icon_check"' EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; status=1; }
if [[ ! -d "$app/Contents" ]]; then
    echo "FAIL: application bundle not found" >&2
    exit 1
fi

if codesign --verify --deep --strict "$app" >/dev/null 2>&1; then
    pass "code and sealed-resource integrity"
else
    fail "code or sealed-resource integrity"
fi
signature=$(codesign -dv --verbose=4 "$app" 2>&1 || true)
if [[ "$signature" == *"Authority=Developer ID Application:"* && "$signature" != *"Signature=adhoc"* ]]; then
    pass "Developer ID Application signature"
else
    fail "Developer ID Application signature required"
fi
flags=$(sed -n 's/^CodeDirectory .*flags=//p' <<< "$signature")
if [[ "$flags" == *runtime* ]]; then pass "hardened runtime"; else fail "hardened runtime required"; fi
if [[ "$signature" == *"Timestamp="* ]]; then pass "secure signing timestamp"; else fail "secure signing timestamp required"; fi

identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || true)
if [[ "$identifier" == "io.github.alfredtutu.waterline" ]]; then pass "production bundle identifier"; else fail "production bundle identifier required"; fi
minimum=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist" 2>/dev/null || true)
build_info=$(xcrun vtool -show-build "$app/Contents/MacOS/WaterlineApp" 2>/dev/null || true)
deployment_targets=$(awk '$1 == "minos" { print $2 }' <<< "$build_info")
targets_match=true
while read -r target; do
    case "$target" in 14.0|14.0.0) ;; *) targets_match=false ;; esac
done <<< "$deployment_targets"
if [[ "$minimum" == "14.0" && -n "$deployment_targets" ]] && $targets_match; then
    pass "declared and compiled macOS 14 deployment target"
else
    fail "declared and compiled macOS 14 deployment target required"
fi
accessory=$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app/Contents/Info.plist" 2>/dev/null || true)
if [[ "$accessory" == "true" ]]; then pass "accessory-app bundle setting"; else fail "accessory-app bundle setting required"; fi
provider_assets_match=true
for logo in Resources/ProviderLogos/Provider-*.png; do
    if ! cmp -s "$logo" "$app/Contents/Resources/$(basename "$logo")"; then provider_assets_match=false; fi
done
if ! cmp -s Resources/ProviderLogos/LICENSE.txt "$app/Contents/Resources/ProviderLogos-LICENSE.txt"; then provider_assets_match=false; fi
if $provider_assets_match; then pass "provider logos and license match reviewed resources"; else fail "provider logos or license missing or changed"; fi
icon_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist" 2>/dev/null || true)
if [[ "$icon_name" == "AppIcon" ]] && iconutil -c iconset "$app/Contents/Resources/AppIcon.icns" -o "$icon_check/AppIcon.iconset" >/dev/null 2>&1; then
    icon_complete=true
    for size in 16 32 128 256 512; do
        for scale in "" "@2x"; do
            if [[ ! -s "$icon_check/AppIcon.iconset/icon_${size}x${size}${scale}.png" ]]; then icon_complete=false; fi
        done
    done
    if $icon_complete; then pass "application icon representations"; else fail "incomplete application icon representations"; fi
else
    fail "declared, decodable application icon required"
fi
if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then pass "release version format"; else fail "stable release version required"; fi

if [[ "$mode" == --pre-notarization ]]; then
    echo "Pre-notarization checks only; ticket and Gatekeeper acceptance remain unchecked."
    exit "$status"
fi

if xcrun stapler validate "$app" >/dev/null 2>&1; then
    pass "stapled notarization ticket"
else
    fail "valid stapled notarization ticket required"
fi
assessment_state=$(spctl --status 2>&1 || true)
if [[ "$assessment_state" != "assessments enabled" ]]; then
    fail "Gatekeeper assessment disabled or unavailable; acceptance cannot be inferred"
else
    if assessment=$(spctl --assess --type execute --verbose "$app" 2>&1); then
        if [[ "$assessment" == *"override="* ]]; then
            fail "Gatekeeper result uses a local override"
        else
            pass "Gatekeeper assessment on this machine"
        fi
    else
        fail "Gatekeeper rejected the application"
    fi
fi
exit "$status"
