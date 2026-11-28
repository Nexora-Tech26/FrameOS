import json, os, pathlib, subprocess, sys, urllib.request, urllib.parse, zipfile, io, shutil
root=pathlib.Path(sys.argv[1])
report=pathlib.Path(sys.argv[2])
version=subprocess.check_output(['chroot',str(root),'gnome-shell','--version'],text=True).strip().split()[-1].split('.')[0]
extensions=[
('dash-to-dock@micxgx.gmail.com','Dash to Dock',True),
('openbar@neuromorph','Open Bar',True),
('kiwimenu@kemma','Kiwi Menu',True),
('blur-my-shell@aunetx','Blur My Shell',False),
('desktop-cube@schneegans.github.com','Desktop Cube',False),
('clipboard-indicator@tudmotu.com','Clipboard Indicator',True),
('user-theme@gnome-shell-extensions.gcampax.github.com','User Themes',False),
('just-perfection-desktop@just-perfection','Just Perfection',False),
('gsconnect@andyholmes.github.io','GSConnect',False),
('rounded-window-corners@fxgn','Rounded Window Corners Reborn',False),
('appindicatorsupport@rgcjonas.gmail.com','AppIndicator',True),
('caffeine@patapon.info','Caffeine',True),
('quick-settings-tweaks@qwreey','Quick Settings Tweaker',False)]
dest=root/'usr/share/gnome-shell/extensions'
dest.mkdir(parents=True,exist_ok=True)
enabled=[]; results=[]
def get(url):
    req=urllib.request.Request(url,headers={'User-Agent':'FrameOS build/1.0'})
    with urllib.request.urlopen(req,timeout=30) as r: return r.read()
for uuid,name,active in extensions:
    target=dest/uuid
    try:
        info=json.loads(get('https://extensions.gnome.org/extension-info/?'+urllib.parse.urlencode({'uuid':uuid,'shell_version':version})))
        release=info.get('shell_version_map',{}).get(version)
        link=('/download-extension/'+urllib.parse.quote(uuid,safe='@.')+'.shell-extension.zip?version_tag='+str(release['pk'])) if release and release.get('pk') else info.get('download_url')
        if not link: raise ValueError('no compatible release')
        blob=get(urllib.parse.urljoin('https://extensions.gnome.org/',link))
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            meta=json.loads(z.read('metadata.json'))
            if meta['uuid']!=uuid: raise ValueError(f"UUID mismatch: {meta['uuid']}")
            if version not in [str(v).split('.')[0] for v in meta['shell-version']]: raise ValueError(f"GNOME {version} unsupported by downloaded release; supports {meta['shell-version']}")
            for item in z.infolist():
                path=pathlib.PurePosixPath(item.filename)
                if path.is_absolute() or '..' in path.parts or (item.external_attr>>16)&0o170000==0o120000: raise ValueError('unsafe archive')
            target.mkdir(exist_ok=True)
            z.extractall(target)
        if (target/'schemas').is_dir(): subprocess.run(['glib-compile-schemas','--strict',str(target/'schemas')],check=True)
        if active: enabled.append(uuid)
        results.append({'name':name,'uuid':uuid,'version':meta.get('version'),'status':'enabled by default' if active else 'installed, opt-in'})
    except Exception as e:
        if target.exists(): shutil.rmtree(target)
        results.append({'name':name,'uuid':uuid,'status':'unavailable','reason':str(e)})
# Prefer official Open Bar; fall back to a pinned GNOME 50 community port.
if version == '50' and 'openbar@neuromorph' not in enabled:
    uuid='openbar@ddevel'
    target=dest/uuid
    try:
        commit='3047287ac3443879a86d69d1e31a48a9f23e1a92'
        blob=get('https://codeload.github.com/d-devel/openbar/zip/'+commit)
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            prefix='openbar-'+commit+'/'+uuid+'/'
            for item in z.infolist():
                if not item.filename.startswith(prefix): continue
                name=item.filename[len(prefix):]
                if not name: continue
                path=pathlib.PurePosixPath(name)
                if path.is_absolute() or '..' in path.parts or (item.external_attr>>16)&0o170000==0o120000: raise ValueError('unsafe archive')
                destfile=target/path
                if item.is_dir(): destfile.mkdir(parents=True,exist_ok=True)
                else:
                    destfile.parent.mkdir(parents=True,exist_ok=True)
                    destfile.write_bytes(z.read(item))
        meta=json.loads((target/'metadata.json').read_text())
        if meta['uuid']!=uuid or version not in meta['shell-version']: raise ValueError('incompatible port')
        subprocess.run(['glib-compile-schemas','--strict',str(target/'schemas')],check=True)
        enabled.append(uuid)
        results.append({'name':'Open Bar GNOME 50 port','uuid':uuid,'status':'enabled by default','commit':commit})
    except Exception as e:
        if target.exists(): shutil.rmtree(target)
        results.append({'name':'Open Bar GNOME 50 port','uuid':uuid,'status':'unavailable','reason':str(e)})
# Apply only settings supported by installed schemas. User Themes gets full Orchis Shell base.
import xml.etree.ElementTree as ET
bar={'bartype':"'Trilands'",'boxalpha':'0.0','bgalpha':'0.0','isalpha':'0.94','bradius':'16.0','height':'34.0','margin':'6.0','hpad':'8.0','vpad':'3.0','bwidth':'0.0','shadow':'false','neon':'false','gradient':'false','candybar':'false','wmaxbar':'false','set-overview':'true','apply-gtk':'false','apply-flatpak':'false','set-yarutheme':'false','apply-all-shell':'false','traffic-light':'false','heffect':'false','halpha':'0.22','menu-radius':'16.0','notif-radius':'16.0'}
settings={
'dash-to-dock@micxgx.gmail.com':{'dock-position':"'BOTTOM'",'show-apps-at-top':'false','show-show-apps-button':'true','extend-height':'false','dash-max-icon-size':'40','dock-fixed':'true','autohide':'false','intellihide':'false','custom-theme-shrink':'true','show-trash':'false','show-mounts':'false'},
'openbar@neuromorph':bar,
'openbar@ddevel':bar,
'user-theme@gnome-shell-extensions.gcampax.github.com':{'name':"'Frame-Glass'"}}
# Native GNOME panel, clock, notification center and Quick Settings remain untouched.
lines=['[org/gnome/shell]','disable-user-extensions=false','enabled-extensions='+repr(enabled),'','[org/gnome/desktop/interface]','enable-animations=true','']
for uuid,values in settings.items():
    if uuid not in enabled: continue
    for f in (dest/uuid/'schemas').glob('*.xml'):
        for schema in ET.parse(f).getroot().findall('schema'):
            path=schema.get('path')
            if not path: continue
            keys={k.get('name') for k in schema.findall('key')}
            selected={k:v for k,v in values.items() if k in keys}
            if selected: lines+=['['+path.strip('/')+']']+[k+'='+v for k,v in selected.items()]+['']
(root/'etc/dconf/db/local.d/20-frame-desktop').write_text('\n'.join(lines))
report.write_text(json.dumps({'gnome':version,'extensions':results,'panel':'Open Bar Trilands' if any(x in enabled for x in ('openbar@neuromorph','openbar@ddevel')) else 'Native GNOME panel','animations':True},indent=2))
print(report.read_text())
# Required desktop controls must not silently disappear.
if 'dash-to-dock@micxgx.gmail.com' not in enabled: raise SystemExit('No compatible Dash to Dock release')
