#!/bin/bash
set -Eeuo pipefail
log="$HOME/.local/state/frameos-installer.log"
mkdir -p "$(dirname "$log")"
if ! sudo -n /usr/bin/env DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" QT_QPA_PLATFORM=xcb /usr/bin/calamares -d >"$log" 2>&1; then
  zenity --error --text="Installer could not start. See $log" || true
  exit 1
fi
