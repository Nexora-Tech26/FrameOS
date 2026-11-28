#!/usr/bin/python3
import gi, json, pathlib, subprocess
gi.require_version("Gtk","4.0")
gi.require_version("Adw","1")
from gi.repository import Gtk, Adw, Gio
uuid="dash-to-dock@micxgx.gmail.com"
class App(Adw.Application):
    def __init__(self): super().__init__(application_id="org.frameos.Modes")
    def do_activate(self):
        w=Adw.ApplicationWindow(application=self,title="Mode",default_width=540,default_height=440)
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=16)
        for edge in ("top","bottom","start","end"): getattr(box,"set_margin_"+edge)(24)
        box.append(Adw.HeaderBar())
        title=Gtk.Label(label="System Mode"); title.add_css_class("title-1"); box.append(title)
        self.status=Gtk.Label(wrap=True); box.append(self.status)
        for name,desc in [("Basic","Standard desktop"),("Touch","Full-width, fixed dock and larger controls"),("Play","Standard dock with gaming tools available")]:
            b=Gtk.Button(label=name+" — "+desc); b.connect("clicked",self.apply,name); box.append(b)
        w.set_content(box); w.present()
    def apply(self,button,name):
        try:
            schema_dir="/usr/share/gnome-shell/extensions/"+uuid+"/schemas"
            source=Gio.SettingsSchemaSource.new_from_directory(schema_dir,Gio.SettingsSchemaSource.get_default(),False)
            schema=source.lookup("org.gnome.shell.extensions.dash-to-dock",False)
            settings=Gio.Settings.new_full(schema,None,None)
            touch=name=="Touch"
            values={"extend-height":touch,"dock-fixed":True,"autohide":False,"intellihide":False,"show-apps-at-top":False,"show-show-apps-button":True,"dash-max-icon-size":56 if touch else 40}
            for key,value in values.items():
                if schema.has_key(key):
                    if isinstance(value,bool): settings.set_boolean(key,value)
                    else: settings.set_int(key,value)
            config=pathlib.Path.home()/".config/frameos"
            config.mkdir(parents=True,exist_ok=True)
            (config/"mode.json").write_text(json.dumps({"mode":name}))
            self.status.set_text(name+" mode applied. Play performance tools are optional and require supported games.")
        except Exception as exc: self.status.set_text(str(exc))
App().run(None)
