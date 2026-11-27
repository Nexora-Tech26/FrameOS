import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class FrameIntegration extends Extension {
    enable() {
        this._items=[];
        this._settings=new Gio.Settings({schema_id:'org.gnome.desktop.interface'});
        this._shellSettings=new Gio.Settings({schema_id:'org.gnome.shell'});
        this._tracker=Shell.WindowTracker.get_default();
        this._vm=false;
        try { this._vm=GLib.spawn_command_line_sync('systemd-detect-virt --vm')[3]===0; } catch(e) {}
        this._originalStyles=new Map();
        this._originalClock=null;
        this._focusId=global.display.connect('notify::focus-window',()=>this._refresh());
        this._appButton=this._button('Desktop','left',1);
        // Keep native clock and quick settings actors alive: reparent only the date menu container.
        const clock=Main.panel.statusArea.dateMenu;
        if(clock?.container && clock.container.get_parent()===Main.panel._centerBox){
            this._originalClock={actor:clock.container,parent:Main.panel._centerBox,index:Main.panel._centerBox.get_children().indexOf(clock.container)};
            Main.panel._centerBox.remove_child(clock.container);
            Main.panel._rightBox.insert_child_at_index(clock.container,0);
        }
        for(const [name,actions] of [
          ['File',[['Open application launcher',()=>Main.overview.showApps()],['New window',()=>this._app()?.open_new_window(-1)],['Close window',()=>this._window()?.delete(global.get_current_time())]]],
          ['Edit',[['Application settings',()=>this._launch('org.gnome.Settings.desktop')]]],
          ['View',[['Toggle maximize',()=>{const w=this._window();if(w){if(w.get_maximized())w.unmaximize(Meta.MaximizeFlags.BOTH);else w.maximize(Meta.MaximizeFlags.BOTH);}}],['Toggle fullscreen',()=>{const w=this._window();if(w){if(w.is_fullscreen())w.unmake_fullscreen();else w.make_fullscreen();}}],['Overview',()=>Main.overview.toggle()]]],
          ['Help',[['System information',()=>this._launch('org.gnome.Settings.desktop')],['GNOME Help',()=>this._launch('yelp.desktop')]]]
        ]){
            const b=this._button(name,'center',-1);
            for(const [label,fn] of actions)this._action(b,label,fn);
        }
        const c=this._button('','right',0,'preferences-system-symbolic');
        this._action(c,'Settings',()=>this._launch('org.gnome.Settings.desktop'));
        this._action(c,'Network',()=>this._spawn(['gnome-control-center','network']));
        this._action(c,'Sound',()=>this._spawn(['gnome-control-center','sound']));
        this._action(c,'Displays',()=>this._spawn(['gnome-control-center','display']));
        this._action(c,'Toggle dark appearance',()=>this._settings.set_string('color-scheme',this._settings.get_string('color-scheme')==='prefer-dark'?'default':'prefer-dark'));
        this._action(c,'Toggle animations',()=>this._settings.set_boolean('enable-animations',!this._settings.get_boolean('enable-animations')));
        this._action(c,'Performance mode',()=>this._performance());
        this._action(c,'Extensions',()=>this._spawn(['gnome-extensions-app']));
        this._refresh();
        if(this._vm)this._performance();
        // Lightweight Trilands-inspired fallback without a shader or blur.
        if(!this._shellSettings.get_strv('enabled-extensions').includes('openbar@neuromorph')){
            for(const box of [Main.panel._leftBox,Main.panel._centerBox,Main.panel._rightBox]){
                this._originalStyles.set(box,box.get_style());
                box.add_style_class_name('frame-island');
            }
            Main.panel.add_style_class_name('frame-panel');
        }
    }
    _window(){return global.display.focus_window;}
    _app(){const w=this._window();return w?this._tracker.get_window_app(w):null;}
    _refresh(){if(this._appButton)this._appButton._frameLabel.text=this._app()?.get_name()??'Desktop';}
    _spawn(args){try{Gio.Subprocess.new(args,Gio.SubprocessFlags.NONE);}catch(e){Main.notify('FrameOS',String(e));}}
    _launch(id){const app=Shell.AppSystem.get_default().lookup_app(id);if(app)app.activate();else Main.notify('FrameOS','Application not available');}
    _button(text,side,pos,icon=null){
        const b=new PanelMenu.Button(0.0,'FrameOS '+(text||'Control Center'),false);
        const label=new St.Label({text,y_align:Clutter.ActorAlign.CENTER});
        b._frameLabel=label;
        b.add_child(icon?new St.Icon({icon_name:icon,style_class:'system-status-icon'}):label);
        Main.panel.addToStatusArea('frame-'+this._items.length,b,pos<0?this._items.length:pos,side);
        this._items.push(b);return b;
    }
    _action(b,label,fn){const item=new PopupMenu.PopupMenuItem(label);item.connect('activate',()=>{try{fn();}catch(e){Main.notify('FrameOS',String(e));}});b.menu.addMenuItem(item);}
    _performance(){
        this._settings.set_boolean('enable-animations',false);
        for(const id of ['blur-my-shell@aunetx','desktop-cube@schneegans.github.com','rounded-window-corners@fxgn'])Main.extensionManager.disableExtension(id);
    }
    disable(){
        if(this._focusId)global.display.disconnect(this._focusId);
        this._focusId=0;
        for(const b of this._items??[])b.destroy();
        this._items=[];
        if(this._originalClock){const {actor,parent,index}=this._originalClock;actor.get_parent()?.remove_child(actor);parent.insert_child_at_index(actor,index);this._originalClock=null;}
        for(const [box] of this._originalStyles??[])box.remove_style_class_name('frame-island');
        Main.panel.remove_style_class_name('frame-panel');
        this._originalStyles=null;
        this._appButton=null;this._settings=null;this._shellSettings=null;this._tracker=null;
    }
}
