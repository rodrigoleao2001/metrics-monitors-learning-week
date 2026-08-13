#!/usr/bin/env bash
# Opens the Learning Week lab control panel in your browser.
#
#   ./start-ui.sh
#
# On a Mac you can double-click "Start Learning Week.app" in the Finder instead.
#
# Leave this terminal window open while you use the panel. Press Ctrl+C to stop
# it. Stopping the panel does not stop any lab you started.
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

# The server opens the browser itself, once its socket is actually listening.
exec "$PY" lab-ui/server.py
