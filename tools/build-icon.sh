#!/bin/bash
# Produce the standard macOS icon representations from the project-owned source artwork.
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:?usage: build-icon.sh output.icns}"
staging=$(mktemp -d "${TMPDIR:-/tmp}/waterline-icon.XXXXXX")
trap 'rm -rf "$staging"' EXIT
iconset="$staging/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" app/Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" app/Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$output"
