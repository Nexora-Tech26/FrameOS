#!/usr/bin/python3
import os
import sys
import subprocess
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gio, GLib

if "boot=casper" not in open("/proc/cmdline").read().split():
    raise SystemExit(0)

class Welcome(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.frameos.LiveWelcome")
    def do_activate(self):
        if self.get_active_window():
            self.get_active_window().present()
            return
        window = Gtk.ApplicationWindow(application=self, title="Welcome to FrameOS")
        window.set_default_size(600, 390)
        window.set_resizable(False)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        for side in ("top", "bottom", "start", "end"):
            getattr(box, "set_margin_" + side)(32)
        logo = Gtk.Image.new_from_icon_name("frameos-installer")
        logo.set_pixel_size(72)
        box.append(logo)
        heading = Gtk.Label(label="Welcome to FrameOS")
        heading.add_css_class("title-1")
        box.append(heading)
        subtitle = Gtk.Label(label="Explore the desktop or install FrameOS on your computer.")
        subtitle.set_wrap(True)
        subtitle.set_justify(Gtk.Justification.CENTER)
        box.append(subtitle)
        for title, detail, icon, install in [
            ("Try FrameOS", "Explore without installing", "computer-symbolic", False),
            ("Install FrameOS", "Set up FrameOS on your disk", "drive-harddisk-symbolic", True),
        ]:
            button = Gtk.Button()
            button.add_css_class("suggested-action" if install else "card")
            row = Gtk.Box(spacing=16)
            row.set_margin_top(12)
            row.set_margin_bottom(12)
            row.set_margin_start(16)
            row.set_margin_end(16)
            image = Gtk.Image.new_from_icon_name(icon)
            image.set_pixel_size(32)
            row.append(image)
            labels = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            name = Gtk.Label(label=title, xalign=0)
            name.add_css_class("heading")
            labels.append(name)
            desc = Gtk.Label(label=detail, xalign=0)
            labels.append(desc)
            row.append(labels)
            button.set_child(row)
            button.connect("clicked", self.choose, window, install)
            box.append(button)
        window.set_child(box)
        window.present()
    def choose(self, button, window, install):
        if not install:
            window.close()
            return
        button.set_sensitive(False)
        process = subprocess.Popen(["/usr/local/bin/frameos-install"])
        def check():
            if process.poll() is None:
                return True
            button.set_sensitive(True)
            if process.returncode == 0:
                window.close()
            return False
        GLib.timeout_add(500, check)

Welcome().run(sys.argv)
