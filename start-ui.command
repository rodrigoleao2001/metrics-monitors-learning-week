#!/bin/bash
# Double-clickable entry point for macOS. The Finder hands .command files to
# Terminal, so this gives you a window with the panel's output in it.
#
# "Start Learning Week.app" simply calls this file.
cd "$(dirname "$0")" || exit 1
exec ./start-ui.sh
