#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
base="${1:-.build-cache/ubuntu-26.10-desktop-amd64.iso}"
out="${2:-dist/FrameOS-1.0-part1-amd64.iso}"
mkdir -p "$(dirname "$out")"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
test -s "$base"
test ! -e "$out" || { echo "Output already exists: $out" >&2; exit 1; }
xorriso -abort_on FAILURE -osirrox on -indev "$base" -extract /boot/grub/grub.cfg "$work/grub.cfg"
chmod u+w "$work/grub.cfg"
# Preserve kernel arguments, paths, installer and signed boot components.
python3 - "$work/grub.cfg" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
import re
text, count = re.subn(r'(?m)^(\s*menuentry\s+)(["\'])([^"\'\n]*Ubuntu[^"\'\n]*)(\2)', lambda m: m[1]+m[2]+m[3].replace('Ubuntu','FrameOS (Ubuntu base)')+m[4], text)
if not count:
    raise SystemExit("Upstream GRUB menu layout changed; inspect before proceeding")
p.write_text(text)
PY
printf 'FrameOS 1.0\nDevelopment build: Part 2 fast base (package integration pending)\nBase: Ubuntu 26.10 AMD64\n' > "$work/FRAMEOS.txt"
# Update media checksum entries for modified boot configuration.
xorriso -abort_on FAILURE -osirrox on -indev "$base" -extract /md5sum.txt "$work/md5sum.txt"
chmod u+w "$work/md5sum.txt"
python3 - "$work" <<'PY'
import hashlib, pathlib, sys
p=pathlib.Path(sys.argv[1])
f=p/'md5sum.txt'
lines=f.read_text().splitlines()
mapping={'boot/grub/grub.cfg':p/'grub.cfg','FRAMEOS.txt':p/'FRAMEOS.txt'}
lines=[line for line in lines if line.split(maxsplit=1)[-1].lstrip('*').removeprefix('./') not in mapping]
for name, source in mapping.items():
    lines.append(hashlib.md5(source.read_bytes()).hexdigest()+'  ./'+name)
f.write_text('\n'.join(lines)+'\n')
PY
xorriso -abort_on FAILURE -indev "$base" -outdev "$out" \
  -map "$work/grub.cfg" /boot/grub/grub.cfg \
  -map "$work/FRAMEOS.txt" /FRAMEOS.txt \
  -map "$work/md5sum.txt" /md5sum.txt \
  -boot_image any replay -commit -end
# xorriso report output may go to stderr; capture separately for validation.
xorriso -indev "$out" -report_el_torito plain > "$work/boot.txt" 2>&1
cat "$work/boot.txt" > "$(dirname "$out")/boot-report.txt"
grep -Eq 'El Torito boot img.*UEFI' "$work/boot.txt"
xorriso -abort_on FAILURE -osirrox on -indev "$out" -extract /FRAMEOS.txt "$work/verify.txt"
cmp "$work/FRAMEOS.txt" "$work/verify.txt"
(cd "$(dirname "$out")" && sha256sum "$(basename "$out")" > SHA256SUMS)
