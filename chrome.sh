#!/usr/bin/env bash
# start-chrome-debug.sh
# Launches Google Chrome with CDP remote debugging enabled for Claude Code / MCP attach.
# Uses a local ./chrome-debug profile folder next to this script.
# Works on Ubuntu/Linux and macOS.

set -euo pipefail

PORT=9222
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA_DIR="$SCRIPT_DIR/chrome-debug"

# Candidate Chrome executables (macOS first, then Linux names/paths)
CHROME_CANDIDATES=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "google-chrome"
    "google-chrome-stable"
    "chromium-browser"
    "chromium"
    "/usr/bin/google-chrome"
    "/usr/bin/google-chrome-stable"
    "/usr/bin/chromium-browser"
    "/usr/bin/chromium"
    "/snap/bin/chromium"
)

# Resolve Chrome executable (accept an absolute path that exists, or a command on PATH)
CHROME_EXE=""
for candidate in "${CHROME_CANDIDATES[@]}"; do
    if [[ -x "$candidate" ]]; then
        CHROME_EXE="$candidate"
        break
    elif command -v "$candidate" >/dev/null 2>&1; then
        CHROME_EXE="$(command -v "$candidate")"
        break
    fi
done

if [[ -z "$CHROME_EXE" ]]; then
    echo "Error: Chrome/Chromium not found in the expected locations." >&2
    exit 1
fi

# Warn if Chrome is already running (a live instance will ignore the debug port)
CHROME_BASENAME="$(basename "$CHROME_EXE")"
if pgrep -f "$CHROME_BASENAME" >/dev/null 2>&1; then
    echo "Warning: Chrome appears to be already running. The debug port may be ignored." >&2
    read -r -p "Close all Chrome windows now? (y/N) " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        pkill -f "$CHROME_BASENAME" >/dev/null 2>&1 || true
        sleep 2
    fi
fi

# Ensure the debug profile directory exists
mkdir -p "$USER_DATA_DIR"

# Launch Chrome with remote debugging (in the background so we can verify the endpoint)
echo "Launching Chrome with remote debugging on port $PORT ..."
echo "Profile dir: $USER_DATA_DIR"
"$CHROME_EXE" --remote-debugging-port="$PORT" --user-data-dir="$USER_DATA_DIR" >/dev/null 2>&1 &

# Give it a moment, then verify the CDP endpoint
sleep 3
if command -v curl >/dev/null 2>&1; then
    if tabs="$(curl -fsS --max-time 5 "http://127.0.0.1:$PORT/json" 2>/dev/null)"; then
        echo "CDP endpoint is live. Debuggable page targets:"
        if command -v python3 >/dev/null 2>&1; then
            printf '%s' "$tabs" | python3 -c '
import json, sys
for t in json.load(sys.stdin):
    if t.get("type") == "page":
        print(f"  {t.get(\"title\",\"\")}\t{t.get(\"url\",\"\")}")
'
        else
            printf '%s\n' "$tabs"
        fi
        echo ""
        echo "Attach from Claude Code with: --browserUrl http://127.0.0.1:$PORT"
    else
        echo "Warning: Could not reach http://127.0.0.1:$PORT/json yet. Chrome may still be starting, or the port didn't bind." >&2
    fi
else
    echo "Note: curl not found; skipping CDP endpoint verification." >&2
    echo "Attach from Claude Code with: --browserUrl http://127.0.0.1:$PORT"
fi
