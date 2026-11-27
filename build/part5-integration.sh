#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
base="$PWD/.build-cache/minimal"
ui="$PWD/.build-cache/frameui"
cache="$PWD/.build-cache/desktop"
root="$PWD/.desktop-root"
iso="$PWD/.desktop-iso"
dist="$PWD/dist"
mkdir -p "$cache" "$dist"
if [[ ! -s "$ui/filesystem.squashfs" || ! -s "$base/vmlinuz" ]]; then
  bash build/part3-ui.sh
  rm -f "$dist/FrameOS-1.0-part3-live-amd64.iso"
fi
trap 'sudo rm -rf "$root" "$iso"' EXIT
if [[ ! -s "$cache/filesystem.squashfs" ]]; then
  sudo unsquashfs -no-progress -d "$root" "$ui/filesystem.squashfs"
  # Build full Shell theme on Orchis, not the incomplete Part 3 prototype.
  theme="$root/usr/share/themes/Frame-GTK-Dark/gnome-shell"
  test -s "$theme/gnome-shell.css"
  sudo cp -a "$theme/." "$root/usr/share/themes/Frame-Glass/gnome-shell/"
  sudo tee -a "$root/usr/share/themes/Frame-Glass/gnome-shell/gnome-shell.css" < build/frame-glass.css >/dev/null
  # Import Orchis GTK4 resources for libadwaita rather than applying isolated CSS rules.
  gtk="$root/usr/share/themes/Frame-GTK-Dark/gtk-4.0"
  test -s "$gtk/gtk.css"
  sudo install -d "$root/etc/skel/.config/gtk-4.0"
  sudo cp -a "$gtk/." "$root/etc/skel/.config/gtk-4.0/"
  sudo tee -a "$root/etc/skel/.config/gtk-4.0/gtk.css" < build/frame-gtk.css >/dev/null
  sudo python3 build/install-extensions.py "$root" "$dist/extensions-report.json"
  sudo chown "$(id -u):$(id -g)" "$dist/extensions-report.json"
  sudo chroot "$root" dconf update
  # Keep native calendar and notification services intact; no replacement actors.
  # User can bypass extensions without disabling the graphical desktop.
  sudo install -d "$root/usr/local/bin" "$root/etc/xdg/autostart"
  sudo tee "$root/usr/local/bin/frameos-safe-desktop" >/dev/null <<'EOF'
#!/bin/sh
if grep -qw frameos.safe /proc/cmdline; then
  gsettings set org.gnome.shell disable-user-extensions true
fi
EOF
  sudo chmod 755 "$root/usr/local/bin/frameos-safe-desktop"
  sudo tee "$root/etc/xdg/autostart/frameos-safe-desktop.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=FrameOS Safe Desktop
Exec=/usr/local/bin/frameos-safe-desktop
NoDisplay=true
X-GNOME-Autostart-Phase=Initialization
EOF
  sudo chown -R root:root "$root/usr/share/gnome-shell/extensions" "$root/usr/share/themes" "$root/etc/skel/.config/gtk-4.0"
  sudo du -sb "$root" | cut -f1 > "$cache/filesystem.size"
  sudo mksquashfs "$root" "$cache/filesystem.squashfs.tmp" -noappend -comp zstd -Xcompression-level 3 -b 256K -processors "$(nproc)" -no-progress
  sudo mv "$cache/filesystem.squashfs.tmp" "$cache/filesystem.squashfs"
  sudo cp "$dist/extensions-report.json" "$cache/"
  sudo chown -R "$(id -u):$(id -g)" "$cache"
fi
mkdir -p "$iso/casper" "$iso/boot/grub" "$iso/.disk"
for f in vmlinuz initrd filesystem.manifest; do ln "$base/$f" "$iso/casper/$f"; done
for f in filesystem.squashfs filesystem.size; do ln "$cache/$f" "$iso/casper/$f"; done
printf 'FrameOS 1.0 Part 5 Integration Live AMD64\n' > "$iso/.disk/info"
cat > "$iso/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "Try FrameOS 1.0" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos ---
 initrd /casper/initrd
}
menuentry "FrameOS safe desktop" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos frameos.safe ---
 initrd /casper/initrd
}
menuentry "FrameOS recovery (text console)" {
 linux /casper/vmlinuz boot=casper username=frameos hostname=frameos nomodeset systemd.unit=multi-user.target ---
 initrd /casper/initrd
}
EOF
(cd "$iso" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt)
out="$dist/FrameOS-1.0-part5-live-amd64.iso"
grub-mkrescue -o "$out" "$iso" -- -volid FRAMEOS_1_0
xorriso -indev "$out" -report_el_torito plain > "$dist/boot-report.txt" 2>&1
grep -Eq 'El Torito boot img.*UEFI' "$dist/boot-report.txt"
cp "$base/filesystem.manifest" "$dist/package-manifest.txt"
install -m 0644 "$cache/extensions-report.json" "$dist/extensions-report.json"
stat -c '%s bytes' "$out" > "$dist/size-report.txt"
(cd "$dist" && sha256sum "$(basename "$out")" > SHA256SUMS)
