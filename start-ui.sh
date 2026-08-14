#!/usr/bin/env bash
# Opens the Learning Week lab control panel in your browser.
#
#   ./start-ui.sh              run it here, Ctrl+C to stop
#   LAB_UI_DETACH=1 ./start-ui.sh   run it in the background and return
#
# On a Mac you can double-click "Start Learning Week.app" instead. It hands off
# to this script inside a new Terminal window (an unsigned app bundle cannot
# read files under ~/Desktop itself, but Terminal can), running in the plain
# foreground mode above. Leave that window open while you use the panel; Quit
# in the panel or Ctrl+C in the window stops it.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A folder that arrived as a downloaded or AirDropped zip carries macOS's
# quarantine flag on every file, and Gatekeeper then refuses to launch the
# unsigned app bundle. Running a script from a terminal is never blocked, so
# clearing the flag here is what makes the double-click work from now on. This
# touches only this folder and changes no system setting.
if [ "$(uname -s)" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine \
        "Start Learning Week.app" start-ui.command start-ui.sh lab-ui 2>/dev/null || true
fi

PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
        PY="$c"; break
    fi
done

if [ -z "$PY" ]; then
    echo "Python 3.8 or newer is required and was not found."
    echo "On macOS: brew install python3    On Ubuntu: sudo apt install python3"
    exit 1
fi

PORT="${LAB_UI_PORT:-8765}"
URL="http://127.0.0.1:${PORT}"

open_browser() {
    if command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 || true
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || true
    fi
}

listening() {
    # A bare TCP connect is not enough: a stuck or half-dead process can hold
    # the port accepting connections without ever answering one, which would
    # make this script think the panel is up and just open a browser tab that
    # never loads. Require an actual HTTP response from the state endpoint.
    "$PY" - "$PORT" <<'PY' 2>/dev/null
import sys
import urllib.request
try:
    with urllib.request.urlopen(
            f"http://127.0.0.1:{sys.argv[1]}/api/state", timeout=1.5) as r:
        sys.exit(0 if r.status == 200 else 1)
except Exception:
    sys.exit(1)
PY
}

if [ "${LAB_UI_DETACH:-0}" = "1" ]; then
    # Already up from an earlier launch: just bring the tab forward.
    if listening; then
        echo "The panel is already running at $URL"
        open_browser
        exit 0
    fi

    LOG="lab-ui/server.log"
    : > "$LOG"
    LAB_UI_DETACHED=1 nohup "$PY" -u lab-ui/server.py >> "$LOG" 2>&1 &
    disown 2>/dev/null || true

    # Confirm it really came up, so a failure is reported instead of leaving the
    # participant with a browser tab that cannot connect.
    for _ in $(seq 1 40); do
        if listening; then
            echo "Panel running at $URL"
            echo "Log: $(pwd)/$LOG"
            exit 0
        fi
        sleep 0.25
    done

    echo "The panel did not start. Last lines of $LOG:" >&2
    tail -20 "$LOG" >&2
    exit 1
fi

# The server opens the browser itself, once its socket is actually listening.
exec "$PY" lab-ui/server.py
