#!/bin/bash
# Relaunch only this checkout's bundle; other checkouts and installed copies are independent.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
app="$(pwd -P)/build/Waterline.app"
executable="$app/Contents/MacOS/WaterlineApp"

matching_pids() {
    ps -ww -axo pid=,comm= | awk -v executable="$executable" '
        { pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "") }
        $0 == executable { print pid }
    '
}

while read -r pid; do
    [[ -n "$pid" ]] || continue
    # Recheck after enumeration so a terminated process is not an error or a new target.
    current=$(ps -ww -p "$pid" -o comm= || true)
    if [[ "$current" == "$executable" ]]; then
        kill -TERM "$pid"
    fi
done < <(matching_pids)

for ((attempt=0; attempt<50; attempt++)); do
    [[ -n "$(matching_pids)" ]] || break
    sleep 0.1
done
if [[ -n "$(matching_pids)" ]]; then
    echo "This checkout's Waterline did not exit; its bundle was not replaced." >&2
    exit 1
fi

make app
/usr/bin/open -n "$app"
