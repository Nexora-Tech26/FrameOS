#!/usr/bin/python3
# User-initiated, system Flatpak installation; safe retry for offline installs.
import json, pathlib, subprocess, sys
packs={
 "gaming":["com.valvesoftware.Steam","com.heroicgameslauncher.hgl","net.lutris.Lutris","org.freedesktop.Platform.VulkanLayer.MangoHud"],
 "office":["org.libreoffice.LibreOffice","com.visualstudio.code"],
 "creative":["org.gimp.GIMP","org.kde.krita","org.blender.Blender","org.kde.kdenlive","com.obsproject.Studio"],
 "media":["org.videolan.VLC","org.audacityteam.Audacity"]}
selected=json.loads(pathlib.Path("/etc/frameos/selected-packs.json").read_text()) if pathlib.Path("/etc/frameos/selected-packs.json").exists() else []
if not selected:
 print("No application packs selected."); sys.exit(0)
failed=[]
subprocess.run(["flatpak","remote-add","--user","--if-not-exists","flathub","https://flathub.org/repo/flathub.flatpakrepo"],check=True)
for group in selected:
 for app in packs.get(group,[]):
  if subprocess.run(["flatpak","install","--user","-y","flathub",app]).returncode: failed.append(app)
print("Failed (retry later): "+", ".join(failed) if failed else "Application packs installed.")
sys.exit(bool(failed))
