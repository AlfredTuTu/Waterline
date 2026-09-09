#!/bin/bash
# Structural rules that `swift build` cannot express. Run by `make verify` and CI.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0

if grep -rnE '^\s*import (AppKit|SwiftUI|Cocoa)\b' app/Sources/WaterlineKit; then
    echo "audit: WaterlineKit must stay free of AppKit/SwiftUI"
    status=1
fi

secret_pattern='sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|xai-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{30,}'
if grep -rnE "$secret_pattern" app/Sources app/Tests docs README.md 2>/dev/null; then
    echo "audit: secret-shaped string found; redact it"
    status=1
fi

allowed_dependencies='https://github.com/sparkle-project/Sparkle'
for url in $(grep -oE '\.package\(url: "[^"]+"' app/Package.swift | sed 's/.*"\(.*\)"/\1/'); do
    case " $allowed_dependencies " in
        *" $url "*) ;;
        *) echo "audit: dependency not on the allowlist: $url"; status=1 ;;
    esac
done

for locale in en zh-Hans; do
    if ! plutil -lint "app/Resources/$locale.lproj/Localizable.strings"; then
        status=1
    fi
done

for script in tools/*.sh; do
    if ! bash -n "$script"; then
        status=1
    fi
done

exit $status
