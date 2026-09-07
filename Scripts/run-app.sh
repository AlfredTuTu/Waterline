#!/bin/bash
# Relaunch only this checkout's bundle; other checkouts and installed copies are independent.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
app="$(pwd -P)/build/Waterline.app"
executable="$app/Contents/MacOS/WaterlineApp"
expected_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)

# The app's single-instance guard would otherwise silently keep another build alive.
running_commands=$(ps -ww -axo comm=)
while IFS= read -r running; do
    [[ "$running" != "$executable" ]] || continue
    case "$running" in
        */Contents/MacOS/WaterlineApp)
            bundle="${running%/Contents/MacOS/WaterlineApp}"
            identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist" 2>/dev/null || true)
            if [[ "$identifier" == "$expected_identifier" ]]; then
                echo "Another Waterline copy is running: $bundle" >&2
                echo "Quit that copy before using make run. It has not been stopped or replaced." >&2
                exit 1
            fi
            ;;
    esac
done <<< "$(sed 's/^[[:space:]]*//' <<< "$running_commands")"

matching_pids() {
    ps -ww -axo pid=,comm= | awk -v executable="$executable" '
        { pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "") }
        $0 == executable { print pid }
    '
}

pids=$(matching_pids)
while read -r pid; do
    [[ -n "$pid" ]] || continue
    # Recheck after enumeration so a terminated process is not an error or a new target.
    current=$(ps -ww -p "$pid" -o comm= || true)
    if [[ "$current" == "$executable" ]]; then
        kill -TERM "$pid"
    fi
done <<< "$pids"

for ((attempt=0; attempt<50; attempt++)); do
    pids=$(matching_pids)
    [[ -n "$pids" ]] || break
    sleep 0.1
done
pids=$(matching_pids)
if [[ -n "$pids" ]]; then
    echo "This checkout's Waterline did not exit; its bundle was not replaced." >&2
    exit 1
fi

make app
/usr/bin/open -n "$app"

# Launch Services accepting the request does not prove this build stayed running.
for ((attempt=0; attempt<30; attempt++)); do
    sleep 0.1
    pids=$(matching_pids)
    [[ -n "$pids" ]] || continue
    sleep 1
    pids=$(matching_pids)
    if [[ -n "$pids" ]]; then
        echo "Running $app"
        exit 0
    fi
done
echo "Waterline did not stay running at $app. Check for another copy or a startup failure." >&2
exit 1
