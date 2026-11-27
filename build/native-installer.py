#!/usr/bin/python3
import gi, json, subprocess as sp, sys, threading, pathlib
gi.require_version("Gtk","4.0")
gi.require_version("Adw","1")
from gi.repository import Gtk, Adw, GLib
sys.path.insert(0,"/usr/local/lib/frameos")
import importlib.util
spec=importlib.util.spec_from_file_location("target","/usr/local/lib/frameos/install-target.py")
target=importlib.util.module_from_spec(spec); spec.loader.exec_module(target)
class Installer(Adw.Application):
    def __init__(self):
        super().__init__(application_id="org.frameos.Installer")
    def do_activate(self):
        if self.get_active_window(): self.get_active_window().present(); return
        w=Adw.ApplicationWindow(application=self,title="Install FrameOS",default_width=780,default_height=690)
        self.w=w
        outer=Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.append(Adw.HeaderBar())
        scroll=Gtk.ScrolledWindow(vexpand=True)
        outer.append(scroll)
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=14)
        for side in ("top","bottom","start","end"): getattr(box,"set_margin_"+side)(24)
        scroll.set_child(box)
        h=Gtk.Label(label="Install FrameOS",xalign=0); h.add_css_class("title-1"); box.append(h)
        desc=Gtk.Label(label="Preview · UEFI · Empty virtual disks only · Secure Boot off",wrap=True,xalign=0); box.append(desc)
        self.ds=[d for d in target.disks() if target.eligible(d)]
        def choice(title,items):
            box.append(Gtk.Label(label=title,xalign=0))
            v=Gtk.DropDown.new_from_strings(items); box.append(v); return v
        self.disk=choice("Destination disk (minimum 25 GiB)",[f'{d["name"]} — {d["size"]/1024**3:.1f} GiB — {d.get("model") or ""}' for d in self.ds] or ["No eligible empty disk"])
        self.region=choice("Language / region",["English (United States)","Polski (Polska)"])
        self.zone=choice("Time zone",["Europe/Warsaw","Etc/UTC"])
        self.keyboard=choice("Keyboard",["Polish","US"])
        def entry(title,placeholder,secret=False):
            box.append(Gtk.Label(label=title,xalign=0))
            e=Gtk.Entry(placeholder_text=placeholder,visibility=not secret); box.append(e); return e
        self.user=entry("Username","user")
        self.host=entry("Computer name","frameos-pc"); self.host.set_text("frameos-pc")
        self.password=entry("Password (at least 8 characters)","Password",True)
        self.confirm=entry("Confirm destination: type ERASE followed by disk path","ERASE /dev/sda")
        self.go=Gtk.Button(label="Install FrameOS"); self.go.add_css_class("destructive-action"); self.go.set_sensitive(bool(self.ds)); self.go.connect("clicked",self.start); box.append(self.go)
        self.status=Gtk.Label(label="No disk changes occur until you click Install and confirm the destination.",wrap=True,xalign=0); box.append(self.status)
        self.log=Gtk.TextView(editable=False,monospace=True,wrap_mode=Gtk.WrapMode.WORD_CHAR); self.log.set_size_request(-1,150); box.append(self.log)
        w.set_content(outer); w.present()
    def append(self,line):
        b=self.log.get_buffer(); b.insert(b.get_end_iter(),line); return False
    def start(self,button):
        d=self.ds[self.disk.get_selected()]
        if self.confirm.get_text()!="ERASE "+d["name"]:
            self.status.set_text("Type ERASE "+d["name"]+" to confirm."); return
        if len(self.password.get_text())<8:
            self.status.set_text("Password must contain at least 8 characters."); return
        data=dict(disk=d["name"],size=d["size"],user=self.user.get_text(),host=self.host.get_text(),password=self.password.get_text(),confirm=self.confirm.get_text(),locale=["en_US.UTF-8","pl_PL.UTF-8"][self.region.get_selected()],zone=["Europe/Warsaw","Etc/UTC"][self.zone.get_selected()],keyboard=["pl","us"][self.keyboard.get_selected()])
        button.set_sensitive(False)
        self.status.set_text("Installation in progress. Do not shut down.")
        def worker():
            try:
                p=sp.Popen(["sudo","-n","/usr/bin/python3","/usr/local/lib/frameos/install-target.py"],stdin=sp.PIPE,stdout=sp.PIPE,stderr=sp.STDOUT,text=True)
                p.stdin.write(json.dumps(data)+"\n"); p.stdin.close()
                for line in p.stdout: GLib.idle_add(self.append,line)
                rc=p.wait()
                GLib.idle_add(self.status.set_text,"Installation complete. Shut down and remove the ISO." if rc==0 else "Installation failed. See diagnostic output.")
            except Exception as e: GLib.idle_add(self.status.set_text,str(e))
        threading.Thread(target=worker,daemon=True).start()
Installer().run(sys.argv)
