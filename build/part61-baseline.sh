#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build-cache/upstream dist
base="$PWD/.build-cache/upstream/ubuntu-24.04.5.1-desktop-amd64.iso"
url=https://releases.ubuntu.com/noble
work=$(mktemp -d)
trap 'sudo rm -rf "$work"' EXIT
curl -fsSL --retry 3 "$url/SHA256SUMS" -o "$work/SHA256SUMS"
curl -fsSL --retry 3 "$url/SHA256SUMS.gpg" -o "$work/SHA256SUMS.gpg"
gpgv --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg "$work/SHA256SUMS.gpg" "$work/SHA256SUMS"
grep -F " $(basename "$base")" "$work/SHA256SUMS" > "$work/expected" || grep -F "*$(basename "$base")" "$work/SHA256SUMS" > "$work/expected"
if [[ ! -s "$base" ]]; then curl -fL --retry 3 "$url/$(basename "$base")" -o "$base.tmp"; mv "$base.tmp" "$base"; fi
(cd "$(dirname "$base")"; sha256sum -c "$work/expected")
# First milestone deliberately preserves all upstream installer layers.
bash build/build-iso.sh "$base" dist/FrameOS-1.0-part6.1-installer-baseline-amd64.iso
