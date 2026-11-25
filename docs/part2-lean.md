# FrameOS desktop migration

Fast development builds reuse the verified upstream ISO without recompressing the root filesystem. This build is a base preview, not a completed Part 2.

Package migration plan:
- Remove Ubuntu Dock and Tiling Assistant when configuring the Frame session.
- Replace Ubuntu App Center with GNOME Software and move Thunderbird to the optional Business Pack.
- Replace Yaru, Ubuntu wallpapers and branding once tested Frame GTK, Frame Glass, Fluent and Bibata are ready (Part 3/4/6). Keep fallback assets until replacements work.
- Preserve GNOME Shell, its native Quick Settings backend, installer, kernel, firmware, security updates, Firefox and LibreOffice.
- Implement native Frame Welcome and optional App Packs in Part 14.

Do not delete snap seeds, filesystem layers or package-owned assets independently of package metadata. Actual package removal and Part 2 package integration remain pending. Future modified layers require a SquashFS encoding step; use fast compression and cache them rather than repacking unchanged layers.
