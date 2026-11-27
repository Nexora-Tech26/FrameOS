#!/bin/bash
set -Eeuo pipefail
log="${XDG_STATE_HOME:-$HOME/.local/state}/frameos-installer.log"
mkdir -p "$(dirname "$log")"
exec 3>&2
exec >>"$log" 2>&1
fail() {
  local msg="$1"
  printf '%s\n' "$msg" >&3
  zenity --error --title="Install FrameOS" --text="$msg" --width=460 || true
  exit 1
}
echo "=== $(date -Is) ==="
if ! grep -qw 'boot=casper' /proc/cmdline; then
  fail "The installer is only available in the live session."
fi
if [[ ! -r /cdrom/casper/filesystem.squashfs ]]; then
  fail "Installation media not found at /cdrom/casper/filesystem.squashfs. Log: $log"
fi
if [[ -d /sys/firmware/efi ]] && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
  fail "Secure Boot installation is not supported in this preview."
fi
[[ -n "${DISPLAY:-}" ]] || fail "No XWayland display found. Log: $log"
# Use the current session's X11 cookie, not a global xhost permission.
auth="${XAUTHORITY:-$HOME/.Xauthority}"
[[ -r "$auth" ]] || fail "XWayland authorization file is unavailable. Log: $log"
sudo -n true || fail "The live session could not obtain administrator privileges. Log: $log"
# XWayland provides the Qt xcb display even when GNOME runs on Wayland.
if ! sudo -n /usr/bin/env DISPLAY="$DISPLAY" XAUTHORITY="$auth" QT_QPA_PLATFORM=xcb /usr/bin/calamares -d; then
  fail "Calamares could not start or exited with an error. Log: $log"
fi
