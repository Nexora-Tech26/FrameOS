#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
base="$PWD/.build-cache/minimal"
cache="$PWD/.build-cache/frameui"
root="$PWD/.frameui-root"
iso="$PWD/.frameui-iso"
dist="$PWD/dist"
mkdir -p "$cache" "$dist"
# Reuse Part 2's package layer, without reinstalling the desktop.
if [[ ! -s "$base/filesystem.squashfs" ]]; then
  bash build/minimal-iso.sh
  rm -f "$dist/FrameOS-1.0-part2-minimal-live-amd64.iso"
fi
trap 'sudo rm -rf "$root" "$iso"' EXIT
if [[ ! -s "$cache/filesystem.squashfs" ]]; then
  sudo unsquashfs -no-progress -d "$root" "$base/filesystem.squashfs"
  work=$(mktemp -d)
  trap 'rm -rf "$work"; sudo rm -rf "$root" "$iso"' EXIT
  git clone --depth 1 https://github.com/vinceliuice/Orchis-theme.git "$work/orchis"
  git clone --depth 1 https://github.com/vinceliuice/Fluent-icon-theme.git "$work/fluent"
  mkdir -p "$work/themes" "$work/icons"
  bash "$work/orchis/install.sh" -d "$work/themes" -t grey -c dark light -s standard
  bash "$work/fluent/install.sh" -d "$work/icons"
  sudo cp -a "$work/themes/." "$root/usr/share/themes/"
  sudo cp -a "$work/icons/." "$root/usr/share/icons/"
  theme=$(find "$work/themes" -mindepth 1 -maxdepth 1 -type d -iname '*dark*' -printf '%f\n' | head -1)
  test -n "$theme"
  sudo cp -a "$root/usr/share/themes/$theme" "$root/usr/share/themes/Frame-GTK-Dark"
  light=$(find "$work/themes" -mindepth 1 -maxdepth 1 -type d -iname '*light*' -printf '%f\n' | head -1)
  test -n "$light"
  sudo cp -a "$root/usr/share/themes/$light" "$root/usr/share/themes/Frame-GTK-Light"
  sudo install -d "$root/usr/share/fonts/truetype/frameos"
  for family in inter jetbrainsmono; do
    git clone --depth 1 --filter=blob:none --sparse https://github.com/google/fonts.git "$work/$family"
    git -C "$work/$family" sparse-checkout set "ofl/$family"
    find "$work/$family/ofl/$family" -maxdepth 1 -name '*.ttf' -exec sudo cp {} "$root/usr/share/fonts/truetype/frameos/" \;
    sudo cp "$work/$family/ofl/$family/OFL.txt" "$root/usr/share/fonts/truetype/frameos/$family-OFL.txt"
  done
  sudo chroot "$root" fc-cache -f
  icon=$(find "$work/icons" -mindepth 1 -maxdepth 1 -type d -name 'Fluent*' -printf '%f\n' | sort | head -1)
  test -n "$icon"
  curl -fL --retry 3 https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz -o "$work/cursor.tar.xz"
  sudo tar -xJf "$work/cursor.tar.xz" -C "$root/usr/share/icons"
  test -d "$root/usr/share/icons/Bibata-Modern-Ice"
  for variant in Dark Light; do
    for v in gtk-3.0 gtk-4.0; do
      css="$root/usr/share/themes/Frame-GTK-$variant/$v/gtk.css"
      if [[ -f "$css" ]]; then sudo tee -a "$css" < build/frame-gtk.css >/dev/null; fi
    done
  done
  # GTK4/libadwaita overlay only in the live user's configuration, not global vendor CSS.
  sudo install -d "$root/etc/skel/.config/gtk-4.0"
  sudo install -m 0644 build/frame-gtk.css "$root/etc/skel/.config/gtk-4.0/gtk.css"
  sudo tee "$root/etc/dconf/db/local.d/10-frameui" >/dev/null <<EOF
[org/gnome/desktop/interface]
gtk-theme='Frame-GTK-Dark'
icon-theme='$icon'
cursor-theme='Bibata-Modern-Ice'
cursor-size=24
font-name='Inter 10'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'
clock-show-date=true
clock-show-weekday=true
color-scheme='prefer-dark'
[org/gnome/desktop/notifications]
show-banners=true
[org/gnome/desktop/calendar]
show-weekdate=true
EOF
  sudo chroot "$root" dconf update
  # Verify the Shell calendar service and desktop session files are present.
  sudo find "$root/usr/share/dbus-1/services" "$root/usr/lib" -iname '*calendar*' -print > "$dist/calendar-components.txt"
  sudo chroot "$root" fc-list | grep -iE 'Inter|JetBrains Mono' > "$dist/frameui-fonts.txt"
  test -s "$dist/frameui-fonts.txt"
  cp "$dist/calendar-components.txt" "$dist/frameui-fonts.txt" "$cache/"
  # Keep native GNOME Shell intact; custom shell theming will be enabled with User Themes in Part 4.
  sudo install -d "$root/usr/share/themes/Frame-Glass/gnome-shell"
  sudo install -m 0644 build/frame-glass.css "$root/usr/share/themes/Frame-Glass/gnome-shell/gnome-shell.css"
  sudo du -sb "$root" | cut -f1 > "$cache/filesystem.size"
  sudo mksquashfs "$root" "$cache/filesystem.squashfs.tmp" -noappend -comp zstd -Xcompression-level 3 -b 256K -processors "$(nproc)" -no-progress
  sudo mv "$cache/filesystem.squashfs.tmp" "$cache/filesystem.squashfs"
  sudo chown -R "$(id -u):$(id -g)" "$cache"
fi
mkdir -p "$iso/casper" "$iso/boot/grub" "$iso/.disk"
for f in vmlinuz initrd filesystem.manifest; do ln "$base/$f" "$iso/casper/$f"; done
for f in filesystem.squashfs filesystem.size; do ln "$cache/$f" "$iso/casper/$f"; done
printf 'FrameOS 1.0 Part 3 FrameUI Live AMD64\n' > "$iso/.disk/info"
cat > "$iso/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "Try FrameOS 1.0" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos ---
 initrd /casper/initrd
}
menuentry "FrameOS recovery (text console)" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos nomodeset systemd.unit=multi-user.target ---
 initrd /casper/initrd
}
EOF
(cd "$iso" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt)
out="$dist/FrameOS-1.0-part3-live-amd64.iso"
grub-mkrescue -o "$out" "$iso" -- -volid FRAMEOS_1_0
xorriso -indev "$out" -report_el_torito plain > "$dist/boot-report.txt" 2>&1
grep -Eq 'El Torito boot img.*UEFI' "$dist/boot-report.txt"
cp "$base/filesystem.manifest" "$dist/package-manifest.txt"
for report in calendar-components.txt frameui-fonts.txt; do if [[ -s "$cache/$report" ]]; then cp "$cache/$report" "$dist/$report"; fi; done
stat -c '%s bytes' "$out" > "$dist/size-report.txt"
(cd "$dist" && sha256sum "$(basename "$out")" > SHA256SUMS)
