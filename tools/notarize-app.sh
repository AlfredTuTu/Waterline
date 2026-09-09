#!/bin/bash
# Explicit Apple submission; credentials stay in the caller's existing notarytool Keychain profile.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"

if [[ "${1:-}" == --check && $# == 2 ]]; then
    exec bash tools/check-distribution.sh "$2" --pre-notarization
fi
if [[ $# != 3 ]]; then
    echo "usage: notarize-app.sh --check app" >&2
    echo "       notarize-app.sh app existing-keychain-profile output-app" >&2
    exit 64
fi
app="$1"
profile="$2"
output="$3"
report="${output%.app}-notarization.json"
if [[ -z "$profile" || -e "$output" || -L "$output" || -e "$report" || -L "$report" ]]; then
    echo "Provide an existing notarytool profile and a new output path." >&2
    exit 64
fi
staging=$(mktemp -d "${TMPDIR:-/tmp}/waterline-notarize.XXXXXX")
trap 'rm -rf "$staging"' EXIT
staged_app="$staging/Waterline.app"
ditto "$app" "$staged_app"
bash tools/check-distribution.sh "$staged_app" --pre-notarization
ditto -c -k --keepParent "$staged_app" "$staging/Waterline.zip"
mkdir -p "$(dirname "$report")"
submission_result=0
xcrun notarytool submit "$staging/Waterline.zip" --keychain-profile "$profile" --wait --output-format json > "$staging/result.json" || submission_result=$?
if [[ -s "$staging/result.json" ]]; then
    (set -C; cat "$staging/result.json" > "$report")
fi
if [[ "$submission_result" != 0 ]]; then
    echo "Submission failed; any returned report is preserved at $report." >&2
    exit "$submission_result"
fi
submission_status=$(/usr/bin/plutil -extract status raw -o - "$staging/result.json")
if [[ "$submission_status" != Accepted ]]; then
    echo "Apple did not accept this submission; no notarized output was installed." >&2
    exit 1
fi
xcrun stapler staple "$staged_app"
xcrun stapler validate "$staged_app"
codesign --verify --deep --strict "$staged_app"
# The source bundle stays unchanged; final clean-install/Gatekeeper checks remain separate.
mkdir -p "$(dirname "$output")"
mkdir "$output"
ditto "$staged_app" "$output"
echo "Notarized app: $output"
echo "Run full distribution checks and clean-install acceptance before release."
