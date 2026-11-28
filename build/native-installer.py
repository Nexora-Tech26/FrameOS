#!/usr/bin/python3
import gi, json, subprocess as sp, sys, threading, pathlib, os, re, unicodedata
gi.require_version("Gtk","4.0")
gi.require_version("Adw","1")
from gi.repository import Gtk, Adw, GLib
import importlib.util
spec=importlib.util.spec_from_file_location("target","/usr/local/lib/frameos/install-target.py")
target=importlib.util.module_from_spec(spec); spec.loader.exec_module(target)

STEPS=["Welcome","Language","Keyboard","Installation type","Your account","Review","Installing","Finish"]
def label(text, css=None):
    w=Gtk.Label(label=text,xalign=0,wrap=True)
    if css: w.add_css_class(css)
    return w
def column():
    b=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=16)
    for side in ("top","bottom","start","end"): getattr(b,"set_margin_"+side)(28)
    return b
def drop(items):
    return Gtk.DropDown.new_from_strings(items)

class Installer(Adw.Application):
    def __init__(self):
        super().__init__(application_id="org.frameos.Installer")
        self.step=0
        self.busy=False
        self.ds=[]
        self.disk_id=None
        self.success=False
    def do_activate(self):
        if self.get_active_window(): self.get_active_window().present(); return
        self.w=Adw.ApplicationWindow(application=self,title="Install FrameOS",default_width=920,default_height=620)
        self.w.connect("close-request",lambda *_: self.busy)
        root=Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root.append(Adw.HeaderBar())
        body=Gtk.Box(vexpand=True)
        root.append(body)
        side=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
        side.add_css_class("sidebar"); side.set_size_request(210,-1)
        for edge in ("top","bottom","start","end"): getattr(side,"set_margin_"+edge)(18)
        icon=Gtk.Image.new_from_icon_name("frameos-installer"); icon.set_pixel_size(56)
        side.append(icon); side.append(label("FrameOS 1.0","title-2"))
        self.nav=[]
        for name in STEPS:
            l=label(name); side.append(l); self.nav.append(l)
        body.append(side); body.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))
        self.stack=Gtk.Stack(hexpand=True,vexpand=True)
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        body.append(self.stack)
        self.pages=[]
        for i,name in enumerate(STEPS):
            sc=Gtk.ScrolledWindow(hexpand=True,vexpand=True)
            p=column(); sc.set_child(p); self.stack.add_named(sc,str(i))
            p.append(label(name,"title-1")); self.pages.append(p)
        p=self.pages
        p[0].append(label("Welcome to FrameOS","title-2"))
        p[0].append(label("Install the complete operating system offline. The installer will detect your hardware and prepare the disk automatically."))
        p[0].append(label("Development preview: UEFI, Secure Boot disabled, empty disks only. Use a disposable virtual machine."))
        p[1].append(label("Select the system language and your location. Defaults are based on the live session."))
        self.region=drop(["English (United States)","Polski (Polska)"])
        polish=os.environ.get("LANG","").lower().startswith("pl")
        self.region.set_selected(int(polish))
        p[1].append(label("Language and region")); p[1].append(self.region)
        self.zone=drop(["Europe/Warsaw","Etc/UTC"])
        self.zone.set_selected(0 if polish or str(pathlib.Path("/etc/localtime").resolve()).endswith("/Europe/Warsaw") else 1)
        p[1].append(label("Time zone")); p[1].append(self.zone)
        self.keyboard=drop(["Polish","US"]); self.keyboard.set_selected(0 if polish else 1)
        p[2].append(label("Choose the layout and test your keyboard."))
        p[2].append(self.keyboard)
        p[2].append(Gtk.Entry(placeholder_text="Type here to test your keyboard"))
        p[3].append(label("Automatic installation","title-2"))
        p[3].append(label("A GPT partition table, 512 MiB EFI partition and ext4 system partition will be created automatically."))
        self.disk=drop(["Scanning disks…"]); p[3].append(self.disk)
        self.disk.connect("notify::selected",self.disk_changed)
        self.disk_info=label(""); p[3].append(self.disk_info)
        refresh=Gtk.Button(label="Refresh disks"); refresh.connect("clicked",lambda *_:self.scan()); p[3].append(refresh)
        p[3].append(label("Existing partitions, mounted drives and removable drives are not eligible in this preview. Dual boot and manual partitioning are not yet supported."))
        def entry(title,placeholder="",secret=False):
            p[4].append(label(title)); e=Gtk.Entry(placeholder_text=placeholder,visibility=not secret); p[4].append(e); return e
        self.fullname=entry("Your name","Full name")
        self.user=entry("Username","user")
        self.host=entry("Computer name","frameos-pc"); self.host.set_text("frameos-pc")
        self.password=entry("Password (at least 8 characters)","",True)
        self.repeat=entry("Confirm password","",True)
        self.fullname.connect("changed",self.name_changed)
        self.review=label(""); p[5].append(self.review)
        self.agree=Gtk.CheckButton(label="I confirm installation on the selected disk and understand it will be formatted.")
        self.agree.connect("toggled",lambda *_:self.update_nav()); p[5].append(self.agree)
        self.progress=Gtk.ProgressBar(show_text=True); p[6].append(self.progress)
        self.status=label("Preparing…"); p[6].append(self.status)
        sc=Gtk.ScrolledWindow(vexpand=True,min_content_height=180)
        self.log=Gtk.TextView(editable=False,monospace=True,wrap_mode=Gtk.WrapMode.WORD_CHAR)
        sc.set_child(self.log); p[6].append(sc)
        self.finish=label(""); p[7].append(self.finish)
        self.error=label(""); self.error.add_css_class("error"); root.append(self.error)
        footer=Gtk.Box(spacing=12,halign=Gtk.Align.END)
        for edge in ("top","bottom","start","end"): getattr(footer,"set_margin_"+edge)(16)
        self.back=Gtk.Button(label="Back"); self.back.connect("clicked",lambda *_:self.show(self.step-1)); footer.append(self.back)
        self.next=Gtk.Button(label="Continue"); self.next.add_css_class("suggested-action"); self.next.connect("clicked",self.forward); footer.append(self.next)
        root.append(footer); self.w.set_content(root); self.w.present()
        self.show(0)
        self.scan()
    def name_changed(self,*_):
        name=unicodedata.normalize("NFKD",self.fullname.get_text()).encode("ascii","ignore").decode().lower().split()
        if name:
            self.user.set_text(re.sub("[^a-z0-9_-]","",name[0]))
    def scan(self):
        previous=self.disk_id
        try:
            self.ds=[d for d in target.disks() if d["type"]=="disk"]
        except Exception as e:
            self.ds=[]; self.error.set_text("Disk scan failed: "+str(e))
        names=[]
        for d in self.ds:
            ok=target.eligible(d)
            names.append(f'{d["name"]} — {d["size"]/1024**3:.1f} GiB — {d.get("model") or "Disk"}'+("" if ok else " (not eligible)"))
        self.disk.set_model(Gtk.StringList.new(names or ["No disks found"]))
        selected=next((i for i,d in enumerate(self.ds) if d["name"]==previous and target.eligible(d)),None)
        if selected is None: selected=next((i for i,d in enumerate(self.ds) if target.eligible(d)),0)
        self.disk.set_selected(selected)
        self.disk_changed()
    def selected(self):
        i=self.disk.get_selected()
        return self.ds[i] if i<len(self.ds) else None
    def disk_changed(self,*_):
        if not hasattr(self,"disk_info"): return
        d=self.selected()
        self.disk_id=d["name"] if d else None
        self.disk_info.set_text(("Automatic partitioning available for "+d["name"] if target.eligible(d) else "This disk is not eligible for automatic installation.") if d else "Connect an empty disk of at least 25 GiB.")
        self.agree.set_active(False) if hasattr(self,"agree") else None
        if hasattr(self,"next"): self.update_nav()
    def show(self,n):
        self.step=n; self.stack.set_visible_child_name(str(n)); self.error.set_text("")
        for i,l in enumerate(self.nav):
            l.remove_css_class("heading")
            if i==n: l.add_css_class("heading")
        if n==3: self.scan()
        if n==5:
            d=self.selected()
            self.review.set_text(f'Disk: {d["name"]} — {d["size"]/1024**3:.1f} GiB\nPartitioning: automatic GPT / EFI / ext4\nLanguage: {self.region.get_selected_item().get_string()}\nKeyboard: {self.keyboard.get_selected_item().get_string()}\nTime zone: {self.zone.get_selected_item().get_string()}\nAccount: {self.user.get_text()}\nComputer: {self.host.get_text()}')
            self.agree.set_active(False)
        self.update_nav()
    def update_nav(self):
        self.back.set_sensitive(0<self.step<6 and not self.busy)
        self.next.set_label("Install" if self.step==5 else "Close" if self.step==7 else "Continue")
        ok=self.step!=6 and not self.busy
        if self.step==3:
            d=self.selected(); ok=ok and d is not None and target.eligible(d)
        if self.step==5: ok=ok and self.agree.get_active()
        self.next.set_sensitive(ok)
    def forward(self,*_):
        if self.step==7: self.w.close(); return
        if self.step==4:
            u=self.user.get_text(); h=self.host.get_text(); pw=self.password.get_text()
            if not re.fullmatch(r"[a-z][a-z0-9_-]{0,30}",u) or u in ("root","frameos"):
                self.error.set_text("Enter a valid username."); return
            if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9-]{0,62}",h) or h.endswith("-"):
                self.error.set_text("Enter a valid computer name."); return
            if len(pw)<8 or pw!=self.repeat.get_text() or any(c in pw for c in "\n\r:"):
                self.error.set_text("Passwords must match and contain at least eight valid characters."); return
        if self.step==5: self.start(); return
        self.show(self.step+1)
    def append(self,line):
        b=self.log.get_buffer(); b.insert(b.get_end_iter(),line)
        for prefix,progress in [("Partitioning",.10),("Extracting",.25),("Removing",.70),("Configuring",.85),("Installation complete",1.0)]:
            if line.startswith(prefix): self.progress.set_fraction(progress); self.status.set_text(line.strip()); break
        return False
    def done(self,rc,message=""):
        self.busy=False; self.success=rc==0
        if self.success:
            self.progress.set_fraction(1); self.finish.set_text("FrameOS is installed. Shut down, remove the ISO and boot from the installed disk.")
            self.show(7)
        else:
            self.status.set_text("Installation failed. Review the log below. "+message)
            self.next.set_label("Close"); self.next.set_sensitive(True)
            self.show(7); self.finish.set_text("Installation failed. The target may contain an incomplete system. Return to the live desktop; do not boot the target until fixed. "+message)
            self.pages[7].append(Gtk.Label(label="See /tmp/frameos-install.log in the live session.",wrap=True))
        return False
    def start(self):
        d=self.selected()
        if not d or not target.eligible(d) or not self.agree.get_active(): return
        data=dict(disk=d["name"],size=d["size"],user=self.user.get_text(),host=self.host.get_text(),password=self.password.get_text(),confirm="ERASE "+d["name"],locale=["en_US.UTF-8","pl_PL.UTF-8"][self.region.get_selected()],zone=["Europe/Warsaw","Etc/UTC"][self.zone.get_selected()],keyboard=["pl","us"][self.keyboard.get_selected()])
        self.busy=True; self.show(6)
        def worker():
            try:
                p=sp.Popen(["sudo","-n","/usr/bin/python3","/usr/local/lib/frameos/install-target.py"],stdin=sp.PIPE,stdout=sp.PIPE,stderr=sp.STDOUT,text=True)
                p.stdin.write(json.dumps(data)+"\n"); p.stdin.close()
                with open("/tmp/frameos-install.log","w") as log:
                    for line in p.stdout:
                        log.write(line); log.flush(); GLib.idle_add(self.append,line)
                GLib.idle_add(self.done,p.wait())
            except Exception as e: GLib.idle_add(self.done,1,str(e))
        threading.Thread(target=worker,daemon=True).start()
Installer().run(sys.argv)
