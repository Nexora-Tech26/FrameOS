#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export DEBIAN_FRONTEND=noninteractive
suite=stonking
mirror=https://archive.ubuntu.com/ubuntu
cache="$PWD/.build-cache/minimal"
root="$PWD/.build-root"
iso="$PWD/.build-iso"
dist="$PWD/dist"
mkdir -p "$cache" "$dist"
sudo mkdir -p "$root"
cleanup() {
  for p in run sys proc dev; do
    if mountpoint -q "$root/$p"; then sudo umount -R "$root/$p"; fi
  done
  sudo rm -rf "$root" "$iso"
}
trap cleanup EXIT
if [[ ! -s "$cache/filesystem.squashfs" || ! -s "$cache/vmlinuz" || ! -s "$cache/initrd" || ! -s "$cache/filesystem.manifest" ]]; then
  sudo debootstrap --arch=amd64 --variant=minbase --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg --include=ca-certificates "$suite" "$root" "$mirror"
  sudo tee "$root/etc/apt/sources.list" >/dev/null <<EOF
deb $mirror $suite main restricted universe multiverse
deb $mirror $suite-updates main restricted universe multiverse
deb https://security.ubuntu.com/ubuntu $suite-security main restricted universe multiverse
EOF
  sudo rm -f "$root/etc/resolv.conf"
  sudo cp -L /etc/resolv.conf "$root/etc/resolv.conf"
  for p in dev proc sys; do sudo mount --rbind "/$p" "$root/$p"; sudo mount --make-rslave "$root/$p"; done
  sudo mkdir -p "$root/run"
  sudo mount -t tmpfs tmpfs "$root/run"
  printf '#!/bin/sh\nexit 101\n' | sudo tee "$root/usr/sbin/policy-rc.d" >/dev/null
  sudo chmod +x "$root/usr/sbin/policy-rc.d"
  inroot() { sudo chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive "$@"; }
  inroot apt-get update
  # Prevent Ubuntu-specific desktop extensions, metapackages and themes from entering the base.
  sudo mkdir -p "$root/etc/apt/preferences.d"
  sudo tee "$root/etc/apt/preferences.d/frameos-build" >/dev/null <<'EOF'
Package: ubuntu-desktop ubuntu-desktop-minimal ubuntu-session ubuntu-settings ubuntu-dock gnome-shell-extension-ubuntu-dock gnome-shell-extension-ubuntu-tiling-assistant yaru-theme-* ubuntu-wallpapers* thunderbird ubuntu-welcome
Pin: version *
Pin-Priority: -1
EOF
  packages=(systemd-sysv dbus sudo locales ubuntu-keyring linux-generic linux-firmware casper initramfs-tools grub-common gnome-session gnome-shell gdm3 accountsservice xwayland xserver-xorg-core libpam-systemd polkitd udisks2 gvfs gvfs-backends xdg-desktop-portal-gnome xdg-user-dirs adwaita-icon-theme fonts-dejavu-core network-manager network-manager-gnome wpasupplicant rfkill)
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    IFS='|' read -ra alternatives <<< "$line"
    found=false
    for pkg in "${alternatives[@]}"; do
      if inroot apt-cache show "$pkg" 2>/dev/null | grep '^Package:' >/dev/null; then
        packages+=("$pkg"); found=true; break
      fi
    done
    if [[ "$found" != true ]]; then echo "Required package unavailable: $line" >&2; exit 1; fi
  done < build/part2-packages.txt
  inroot apt-get install -y --no-install-recommends "${packages[@]}"
  # Firefox is distributed by Mozilla's signed APT repository, not the Ubuntu Snap transition.
  sudo mkdir -p "$root/etc/apt/keyrings"
  curl -fsSL --retry 3 https://packages.mozilla.org/apt/repo-signing-key.gpg -o /tmp/frameos-mozilla.asc
  fingerprint=$(gpg --batch --show-keys --with-colons /tmp/frameos-mozilla.asc | awk -F: '$1=="fpr"{print $10;exit}')
  test "$fingerprint" = 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
  sudo install -m 0644 /tmp/frameos-mozilla.asc "$root/etc/apt/keyrings/mozilla.asc"
  echo 'deb [signed-by=/etc/apt/keyrings/mozilla.asc] https://packages.mozilla.org/apt mozilla main' | sudo tee "$root/etc/apt/sources.list.d/mozilla.list"
  printf 'Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' | sudo tee "$root/etc/apt/preferences.d/mozilla"
  inroot apt-get update
  inroot apt-get install -y --no-install-recommends firefox
  inroot flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  sudo sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/;s/^# *pl_PL.UTF-8/pl_PL.UTF-8/' "$root/etc/locale.gen"
  inroot locale-gen
  inroot update-locale LANG=en_US.UTF-8
  inroot systemctl enable NetworkManager gdm3
  inroot systemctl set-default graphical.target
  printf 'FrameOS\n' | sudo tee "$root/etc/hostname"
  # Keep upstream os-release identifiers for package compatibility.
  printf 'FrameOS 1.0 development preview\n' | sudo tee "$root/etc/issue"
  sudo rm -f "$root/usr/sbin/policy-rc.d" "$root/etc/apt/preferences.d/frameos-build"
  inroot update-initramfs -u -k all
  kernel=$(sudo find "$root/boot" -maxdepth 1 -name 'vmlinuz-*' | sort -V | tail -1)
  test -n "$kernel"
  version=${kernel##*/vmlinuz-}
  sudo cp "$kernel" "$cache/vmlinuz"
  sudo cp "$root/boot/initrd.img-$version" "$cache/initrd"
  inroot dpkg-query -W -f='${Package} ${Version}\n' > "$cache/filesystem.manifest"
  if grep -Eq '^(ubuntu-desktop(-minimal)?|ubuntu-session|gnome-shell-extension-ubuntu-dock|gnome-shell-extension-ubuntu-tiling-assistant|yaru-theme-[^ ]+|thunderbird) ' "$cache/filesystem.manifest"; then
    echo 'Unexpected Ubuntu desktop package present' >&2; exit 1
  fi
  inroot apt-get clean
  sudo rm -rf "$root/var/lib/apt/lists/"* "$root/var/cache/apt/archives/"*.deb
  sudo truncate -s 0 "$root/etc/machine-id"
  sudo rm -f "$root/etc/resolv.conf"
  sudo ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
  for p in run sys proc dev; do sudo umount -R "$root/$p"; done
  sudo du -sb "$root" | cut -f1 > "$cache/filesystem.size"
  # Mandatory filesystem packing; fast ZSTD, no expensive XZ recompression.
  sudo mksquashfs "$root" "$cache/filesystem.squashfs.tmp" -noappend -comp zstd -Xcompression-level 3 -b 256K -processors "$(nproc)" -no-progress
  sudo mv "$cache/filesystem.squashfs.tmp" "$cache/filesystem.squashfs"
  sudo chown -R "$(id -u):$(id -g)" "$cache"
fi
mkdir -p "$iso/casper" "$iso/boot/grub" "$iso/.disk"
for f in filesystem.squashfs filesystem.manifest filesystem.size vmlinuz initrd; do
  test -s "$cache/$f"
  ln "$cache/$f" "$iso/casper/$f" || cp "$cache/$f" "$iso/casper/$f"
done
printf 'FrameOS 1.0 Part 2 minimal live AMD64\n' > "$iso/.disk/info"
cat > "$iso/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "Try FrameOS 1.0" {
    linux /casper/vmlinuz boot=casper username=frameos hostname=frameos quiet splash ---
    initrd /casper/initrd
}
menuentry "Try FrameOS (safe graphics)" {
    linux /casper/vmlinuz boot=casper username=frameos hostname=frameos nomodeset ---
    initrd /casper/initrd
}
EOF
(cd "$iso" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt)
out="$dist/FrameOS-1.0-part2-minimal-live-amd64.iso"
grub-mkrescue -o "$out" "$iso" -- -volid FRAMEOS_1_0
xorriso -indev "$out" -report_el_torito plain > "$dist/boot-report.txt" 2>&1
grep -Eq 'El Torito boot img.*UEFI' "$dist/boot-report.txt"
cp "$cache/filesystem.manifest" "$dist/package-manifest.txt"
stat -c '%s bytes' "$out" > "$dist/size-report.txt"
(cd "$dist" && sha256sum "$(basename "$out")" > SHA256SUMS)
