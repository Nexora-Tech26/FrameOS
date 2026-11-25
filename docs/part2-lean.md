# Part 2 lean preview

This is an incremental, experimental remaster of the validated Ubuntu 26.10 ISO. It is not a completed Part 2.

The build recompresses supported main filesystem layers with XZ, removes disposable caches, retains original boot metadata, and records actual sizes. Installer, signed snap seed, kernel and language layers are deliberately preserved. Cached repacked layers are reusable when upstream checksums and the script match.

Pending: dependency-aware package installation and removal in both the target and live layers, including Thunderbird (optional Business Pack), Ubuntu Dock, Tiling Assistant, Ubuntu App Center, redundant apps and languages. Do not remove signed snap seed files without rebuilding their metadata correctly. Preserve Firefox, the full LibreOffice suite, GNOME, firmware and the installer. Retain Yaru as fallback until Frame GTK is available.

Inspect size-report.txt and upstream-layout.txt from the artifact. Successful ISO creation does not prove boot or installation compatibility.
