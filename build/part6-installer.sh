#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
base="$PWD/.build-cache/minimal"
desktop="$PWD/.build-cache/desktop"
cache="$PWD/.build-cache/installer"
root="$PWD/.installer-root"
iso="$PWD/.installer-iso"
dist="$PWD/dist"
mkdir -p "$cache" "$dist"
if [[ ! -s "$desktop/filesystem.squashfs" || ! -s "$base/vmlinuz" ]]; then
  bash build/part5-integration.sh
  rm -f "$dist/FrameOS-1.0-part5-live-amd64.iso"
fi
cleanup() {
  for p in run sys proc dev; do
    if mountpoint -q "$root/$p"; then sudo umount -R "$root/$p"; fi
  done
  sudo rm -rf "$root" "$iso"
}
trap cleanup EXIT
if [[ ! -s "$cache/filesystem.squashfs" || ! -s "$cache/initrd" || ! -s "$cache/vmlinuz" ]]; then
  sudo unsquashfs -no-progress -d "$root" "$desktop/filesystem.squashfs"
  sudo rm -f "$root/etc/resolv.conf"
  sudo cp -L /etc/resolv.conf "$root/etc/resolv.conf"
  for p in dev proc sys; do sudo mount --rbind "/$p" "$root/$p"; sudo mount --make-rslave "$root/$p"; done
  sudo mount -t tmpfs tmpfs "$root/run"
  printf '#!/bin/sh\nexit 101\n' | sudo tee "$root/usr/sbin/policy-rc.d" >/dev/null
  sudo chmod 755 "$root/usr/sbin/policy-rc.d"
  inroot() { sudo chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive "$@"; }
  inroot apt-get update
  # Installed target carries both BIOS and EFI bootloader binaries, without writing host disks.
  inroot apt-get install -y --no-install-recommends grub-pc-bin grub-efi-amd64-bin efibootmgr grub2-common cryptsetup-initramfs os-prober dosfstools e2fsprogs parted btrfs-progs
  sudo install -d "$root/etc/default/grub.d"
  printf 'GRUB_DISTRIBUTOR="FrameOS"\nGRUB_TIMEOUT=5\nGRUB_DISABLE_OS_PROBER=false\n' | sudo tee "$root/etc/default/grub.d/99-frameos.cfg" >/dev/null
  inroot apt-get install -y zenity mokutil sudo squashfs-tools util-linux
  inroot /usr/bin/python3 -c 'import gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk'
  sudo install -D -m 0755 build/native-installer.py "$root/usr/local/bin/frameos-installer-ui"
  sudo install -D -m 0755 build/install-target.py "$root/usr/local/lib/frameos/install-target.py"
  sudo install -d "$root/usr/local/bin" "$root/usr/share/applications" "$root/usr/share/icons/hicolor/scalable/apps"
  sudo install -m 0755 build/launch-installer.sh "$root/usr/local/bin/frameos-install"
  sudo install -m 0755 build/welcome-live.py "$root/usr/local/bin/frameos-welcome"
  sudo install -d "$root/etc/xdg/autostart"
  sudo tee "$root/etc/xdg/autostart/frameos-welcome.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Welcome to FrameOS
Exec=/usr/local/bin/frameos-welcome
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=0
NoDisplay=true
EOF
  sudo install -m 0644 build/installer.desktop "$root/usr/share/applications/frameos-installer.desktop"
  sudo install -m 0644 build/welcome.desktop "$root/usr/share/applications/frameos-welcome.desktop"
  sudo install -m 0644 build/installer/branding/frameos/logo.svg "$root/usr/share/icons/hicolor/scalable/apps/frameos-installer.svg"
  sudo rm -f "$root/usr/sbin/policy-rc.d"
  inroot update-initramfs -u -k all
  kernel=$(sudo find "$root/boot" -maxdepth 1 -name 'vmlinuz-*' | sort -V | tail -1)
  version=${kernel##*/vmlinuz-}
  sudo cp "$kernel" "$cache/vmlinuz"
  sudo cp "$root/boot/initrd.img-$version" "$cache/initrd"
  inroot dpkg-query -W -f='${Package} ${Version}\n' > "$cache/filesystem.manifest"
  inroot apt-get clean
  sudo rm -rf "$root/var/lib/apt/lists/"*
  sudo rm -f "$root/etc/resolv.conf"
  sudo ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
  sudo truncate -s 0 "$root/etc/machine-id"
  for p in run sys proc dev; do sudo umount -R "$root/$p"; done
  sudo du -sb "$root" | cut -f1 > "$cache/filesystem.size"
  sudo mksquashfs "$root" "$cache/filesystem.squashfs.tmp" -noappend -comp zstd -Xcompression-level 3 -b 256K -no-progress
  sudo mv "$cache/filesystem.squashfs.tmp" "$cache/filesystem.squashfs"
  sudo chown -R "$(id -u):$(id -g)" "$cache"
fi
mkdir -p "$iso/casper" "$iso/boot/grub" "$iso/.disk"
for f in vmlinuz initrd filesystem.manifest filesystem.squashfs filesystem.size; do ln "$cache/$f" "$iso/casper/$f"; done
printf 'FrameOS 1.0 Part 6 installer preview AMD64\n' > "$iso/.disk/info"
cat > "$iso/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "FrameOS" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos ---
 initrd /casper/initrd
}
menuentry "FrameOS recovery (text console)" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos nomodeset systemd.unit=multi-user.target ---
 initrd /casper/initrd
}
EOF
(cd "$iso" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt)
out="$dist/FrameOS-1.0-part6-installer-preview-amd64.iso"
grub-mkrescue -o "$out" "$iso" -- -volid FRAMEOS_1_0
xorriso -indev "$out" -report_el_torito plain > "$dist/boot-report.txt" 2>&1
grep -Eq 'El Torito boot img.*UEFI' "$dist/boot-report.txt"
cp "$cache/filesystem.manifest" "$dist/package-manifest.txt"
stat -c '%s bytes' "$out" > "$dist/size-report.txt"
(cd "$dist" && sha256sum "$(basename "$out")" > SHA256SUMS)
