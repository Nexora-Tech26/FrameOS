#!/bin/bash
set -Eeuo pipefail
# Run only inside Calamares target chroot; never modify the live root.
if findmnt -n -o FSTYPE / | grep -Eq '^(overlay|squashfs)$'; then
  echo "Refusing cleanup on live filesystem" >&2
  exit 1
fi
test -f /etc/os-release
export DEBIAN_FRONTEND=noninteractive
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
trap 'rm -f /usr/sbin/policy-rc.d' EXIT
apt-get -y purge casper calamares
rm -f /etc/xdg/autostart/frameos-welcome.desktop /etc/xdg/autostart/frameos-install-mode.desktop /etc/xdg/autostart/frameos-safe-desktop.desktop
rm -f /usr/share/applications/frameos-installer.desktop /usr/share/applications/frameos-welcome.desktop /usr/local/bin/frameos-install /usr/local/bin/frameos-welcome /usr/local/bin/frameos-safe-desktop
rm -f /etc/casper.conf
rm -rf /etc/casper.conf.d
apt-get clean
