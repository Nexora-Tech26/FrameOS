#!/usr/bin/env bash
# Repack only known, optional files in Ubuntu's existing filesystem layers.
# Keep installer source paths and package database unchanged unless using apt.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
base=$(realpath "$1")
out=$(realpath -m "$2")
cache=$(realpath -m ".build-cache/lean-layers")
mkdir -p "$cache" "$(dirname "$out")"
work=$(mktemp -d)
cleanup() { sudo rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/iso"
sudo mount -o loop,ro "$base" "$work/iso"
trap 'sudo umount "$work/iso" || true; cleanup' EXIT
casper="$work/iso/casper"
test -d "$casper"
find "$casper" -maxdepth 1 -type f -printf '%f %s\n' | sort > "$(dirname "$out")/upstream-layout.txt"
cp "$work/iso/boot/grub/grub.cfg" "$work/grub.cfg"
cp "$work/iso/md5sum.txt" "$work/md5sum.txt"
chmod u+w "$work/grub.cfg" "$work/md5sum.txt"
sed -E '/^[[:space:]]*menuentry /s/Ubuntu/FrameOS (Ubuntu base)/g' -i "$work/grub.cfg"
printf 'FrameOS 1.0\nPart 2 lean preview\nUbuntu 26.10 AMD64\n' > "$work/FRAMEOS.txt"
declare -a maps
maps=(-map "$work/grub.cfg" /boot/grub/grub.cfg -map "$work/FRAMEOS.txt" /FRAMEOS.txt)
printf 'before_bytes after_bytes layer\n' > "$(dirname "$out")/size-report.txt"
for image in "$casper"/*.squashfs; do
  name=$(basename "$image")
  # Never edit kernel-specific, language-specific, or installer-only images.
  case "$name" in
    minimal.squashfs|minimal.standard.squashfs|minimal.standard.live.squashfs|filesystem.squashfs) ;;
    *) continue ;;
  esac
  original=$(stat -c%s "$image")
  hash=$(sha256sum "$image" | cut -d' ' -f1)
  result="$cache/$hash-$name"
  if [[ ! -s "$result" && ! -e "$result.skip" ]]; then
    root="$work/root"
    sudo unsquashfs -no-progress -d "$root" "$image"
    # Remove only disposable build/runtime caches, not dpkg metadata,
    # firmware, installer payloads, signed snap seeds or themes.
    for dir in var/cache/apt/archives var/lib/apt/lists var/cache/fontconfig var/tmp; do
      if [[ -d "$root/$dir" && ! -L "$root/$dir" ]]; then
        sudo find "$root/$dir" -xdev -type f ! -name lock -delete
      fi
    done
    sudo mksquashfs "$root" "$work/repacked.squashfs" -noappend -comp xz -b 1M -processors "$(nproc)" -no-progress
    if [[ $(stat -c%s "$work/repacked.squashfs") -lt "$original" ]]; then
      sudo mv "$work/repacked.squashfs" "$result"
      sudo chown "$(id -u):$(id -g)" "$result"
    else
      rm -f "$work/repacked.squashfs"
      # A zero-length sentinel would require repacking each run.
      touch "$result.skip"
    fi
    sudo rm -rf "$root"
  fi
  if [[ -s "$result" ]]; then
    maps+=(-map "$result" "/casper/$name")
    printf '%s %s %s\n' "$original" "$(stat -c%s "$result")" "$name" >> "$(dirname "$out")/size-report.txt"
  else
    printf '%s %s %s\n' "$original" "$original" "$name" >> "$(dirname "$out")/size-report.txt"
  fi
done
# Recalculate checksums for every changed file.
python3 - "$work/md5sum.txt" "${maps[@]}" <<'PY'
import hashlib, pathlib, sys
p=pathlib.Path(sys.argv[1])
args=sys.argv[2:]
mapping={args[i+2].lstrip('/'):pathlib.Path(args[i+1]) for i in range(0,len(args),3)}
lines=[l for l in p.read_text().splitlines() if l.strip() and l.split(maxsplit=1)[-1].lstrip('*').removeprefix('./') not in mapping]
for name, source in mapping.items():
    with source.open('rb') as f:
        digest=hashlib.file_digest(f,'md5').hexdigest()
    lines.append(f'{digest}  ./{name}')
p.write_text('\n'.join(lines)+'\n')
PY
test ! -e "$out"
xorriso -abort_on FAILURE -indev "$base" -outdev "$out" "${maps[@]}" -map "$work/md5sum.txt" /md5sum.txt -boot_image any replay -commit -end
xorriso -indev "$out" -report_el_torito plain > "$(dirname "$out")/boot-report.txt" 2>&1
grep -Eq 'El Torito boot img.*UEFI' "$(dirname "$out")/boot-report.txt"
(cd "$(dirname "$out")" && sha256sum "$(basename "$out")" > SHA256SUMS)
printf 'Original ISO: %s bytes\nNew ISO: %s bytes\n' "$(stat -c%s "$base")" "$(stat -c%s "$out")" | tee -a "$(dirname "$out")/size-report.txt"
