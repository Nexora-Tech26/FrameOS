#!/usr/bin/env bash
set -Eeuo pipefail
root="$1"
inroot() { sudo chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive "$@"; }
# NetworkManager owns DHCP; systemd-resolved owns DNS.
sudo install -d "$root/etc/NetworkManager/conf.d" "$root/etc/netplan" "$root/etc/systemd/resolved.conf.d"
printf '[main]\ndns=systemd-resolved\n' | sudo tee "$root/etc/NetworkManager/conf.d/90-frameos-dns.conf" >/dev/null
printf 'network:\n  version: 2\n  renderer: NetworkManager\n' | sudo tee "$root/etc/netplan/90-frameos.yaml" >/dev/null
sudo chmod 600 "$root/etc/netplan/90-frameos.yaml"
inroot systemctl enable NetworkManager systemd-resolved gdm3
inroot systemctl set-default graphical.target
sudo install -d "$root/etc/gdm3" "$root/etc/dconf/profile" "$root/etc/dconf/db/local.d" "$root/usr/share/backgrounds/frameos" "$root/etc/xdg/autostart"
# GDM login is controlled by Casper for the temporary live account.
# Do not create a passwordless permanent administrator.
sudo install -m 0644 build/frameos-wallpaper.svg "$root/usr/share/backgrounds/frameos/default.svg"
printf 'user-db:user\nsystem-db:local\n' | sudo tee "$root/etc/dconf/profile/user" >/dev/null
sudo tee "$root/etc/dconf/db/local.d/00-frameos" >/dev/null <<'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/frameos/default.svg'
picture-uri-dark='file:///usr/share/backgrounds/frameos/default.svg'
picture-options='zoom'
[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/frameos/default.svg'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
enable-hot-corners=false
[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop','firefox.desktop','libreoffice-writer.desktop','libreoffice-calc.desktop','libreoffice-impress.desktop','org.gnome.Software.desktop','org.gnome.Settings.desktop']
EOF
inroot dconf update
# Disable known vendor first-run launchers and GNOME initial setup in live preview.
for name in ubuntu-welcome ubuntu-report gnome-initial-setup-first-login gnome-initial-setup ubuntu-advantage-notification; do
  printf '[Desktop Entry]\nType=Application\nName=Disabled vendor setup\nHidden=true\n' | sudo tee "$root/etc/xdg/autostart/$name.desktop" >/dev/null
done
# Preserve Ubuntu ID and codename for package compatibility; visible display name is FrameOS.
sudo cp -L "$root/etc/os-release" "$root/etc/os-release.frameos"
sudo sed -i -E 's/^NAME=.*/NAME="FrameOS"/;s/^PRETTY_NAME=.*/PRETTY_NAME="FrameOS 1.0 (Development)"/;s/^VERSION=.*/VERSION="1.0 (Development)"/' "$root/etc/os-release.frameos"
sudo mv -f "$root/etc/os-release.frameos" "$root/etc/os-release"
printf 'FrameOS 1.0\n' | sudo tee "$root/etc/issue" "$root/etc/issue.net" >/dev/null
# Casper uses these values in its live-session greeting and account creation.
sudo install -d "$root/etc/casper.conf.d"
if [[ -f "$root/etc/casper.conf" ]]; then
  sudo sed -i -E 's/^(export[[:space:]]+)?USERNAME=.*/export USERNAME="frameos"/;s/^(export[[:space:]]+)?USERFULLNAME=.*/export USERFULLNAME="FrameOS Live"/;s/^(export[[:space:]]+)?HOST=.*/export HOST="frameos"/' "$root/etc/casper.conf"
fi
# Disable vendor MOTD generators only; retain system diagnostics and real errors.
for file in 00-header 10-help-text 50-motd-news 91-contract-ua-esm-status 95-hwe-eol; do
  if [[ -f "$root/etc/update-motd.d/$file" ]]; then sudo chmod a-x "$root/etc/update-motd.d/$file"; fi
done
# Validate every requested package is actually installed, not merely available.
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  IFS='|' read -ra alternatives <<< "$line"
  found=false
  for pkg in "${alternatives[@]}"; do
    if [[ "$(inroot dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null || true)" == installed ]]; then found=true; break; fi
  done
  [[ "$found" == true ]] || { echo "Missing required package: $line" >&2; exit 1; }
done < build/part2-packages.txt
inroot apt-get check
inroot dpkg-query -W firefox
find "$root/usr/share/applications" -maxdepth 1 -name '*.desktop' -printf '%f\n' | sort > "$PWD/dist/desktop-applications.txt"
test -s "$root/usr/share/backgrounds/frameos/default.svg"
