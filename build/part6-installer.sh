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
if [[ ! -s "$cache/filesystem.squashfs" || ! -s "$cache/target.squashfs" || ! -s "$cache/initrd" || ! -s "$cache/vmlinuz" ]]; then
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
  # Configure target image separately so installed machines never inherit live autologin or installer.
  inroot apt-get purge -y casper
  sudo rm -f "$root/etc/xdg/autostart/frameos-safe-desktop.desktop" "$root/usr/local/bin/frameos-safe-desktop"
  sudo rm -f "$root/usr/sbin/policy-rc.d"
  inroot update-initramfs -u -k all
  inroot apt-get clean
  sudo rm -rf "$root/var/lib/apt/lists/"*
  sudo rm -f "$root/etc/resolv.conf"
  sudo ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
  sudo truncate -s 0 "$root/etc/machine-id"
  for p in run sys proc dev; do sudo umount -R "$root/$p"; done
  sudo mksquashfs "$root" "$cache/target.squashfs.tmp" -noappend -comp zstd -Xcompression-level 3 -b 256K -no-progress
  sudo mv "$cache/target.squashfs.tmp" "$cache/target.squashfs"
  # Add the live-only installer to a fresh copy of Part 5, not the installed target.
  sudo rm -rf "$root"
  sudo unsquashfs -no-progress -d "$root" "$desktop/filesystem.squashfs"
  sudo rm -f "$root/etc/resolv.conf"
  sudo cp -L /etc/resolv.conf "$root/etc/resolv.conf"
  for p in dev proc sys; do sudo mount --rbind "/$p" "$root/$p"; sudo mount --make-rslave "$root/$p"; done
  sudo mount -t tmpfs tmpfs "$root/run"
  printf '#!/bin/sh\nexit 101\n' | sudo tee "$root/usr/sbin/policy-rc.d" >/dev/null
  sudo chmod 755 "$root/usr/sbin/policy-rc.d"
  inroot apt-get update
  inroot apt-get install -y calamares policykit-1-gnome || inroot apt-get install -y calamares
  sudo cp -a build/installer/. "$root/etc/calamares/"
  sudo install -d "$root/usr/local/bin" "$root/usr/share/applications" "$root/usr/share/icons/hicolor/scalable/apps"
  sudo install -m 0755 build/launch-installer.sh "$root/usr/local/bin/frameos-install"
  sudo install -d "$root/etc/xdg/autostart"
  sudo tee "$root/etc/xdg/autostart/frameos-install-mode.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Install FrameOS
Exec=/usr/local/bin/frameos-install --boot-mode
OnlyShowIn=GNOME;
NoDisplay=true
EOF
  sudo install -m 0644 build/installer.desktop "$root/usr/share/applications/frameos-installer.desktop"
  sudo install -m 0644 build/installer/branding/frameos/logo.svg "$root/usr/share/icons/hicolor/scalable/apps/frameos-installer.svg"
  sudo install -d "$root/usr/share/calamares/branding"
  sudo cp -a build/installer/branding/frameos "$root/usr/share/calamares/branding/"
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
mkdir -p "$iso/casper" "$iso/boot/grub" "$iso/.disk" "$iso/install"
for f in vmlinuz initrd filesystem.manifest filesystem.squashfs filesystem.size; do ln "$cache/$f" "$iso/casper/$f"; done
ln "$cache/target.squashfs" "$iso/install/target.squashfs"
printf 'FrameOS 1.0 Part 6 installer preview AMD64\n' > "$iso/.disk/info"
cat > "$iso/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "Try FrameOS 1.0" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos ---
 initrd /casper/initrd
}
menuentry "Install FrameOS 1.0" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos frameos.install=1 ---
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
