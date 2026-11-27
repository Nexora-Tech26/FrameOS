#!/bin/bash
set -e
if [[ "${1:-}" == "--boot-mode" ]]; then
  grep -Eq '(^| )frameos\.install=1( |$)' /proc/cmdline || exit 0
fi
if [[ ! -r /cdrom/install/target.squashfs ]]; then
  zenity --error --text="Installation media not found." || true
  exit 1
fi
if [[ -d /sys/firmware/efi ]] && command -v mokutil >/dev/null && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
  zenity --error --text="Secure Boot installation is not supported in this preview." || true
  exit 1
fi
exec pkexec /usr/bin/calamares
