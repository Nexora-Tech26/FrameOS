#!/usr/bin/python3
"""Preview installer: blank disks only, UEFI only, no Secure Boot."""
import os, sys, json, subprocess as sp, re, pathlib, tempfile, time, fcntl, getpass

IMAGE = "/cdrom/casper/filesystem.squashfs"
def run(*args, **kw):
    print("+", args[0], flush=True)
    return sp.run(args, check=True, **kw)
def output(*args):
    return sp.check_output(args, text=True).strip()
def disks():
    return json.loads(output("lsblk","-J","-b","-p","-o","NAME,TYPE,SIZE,RO,RM,MOUNTPOINTS,FSTYPE,MODEL,PKNAME"))["blockdevices"]
def eligible(d):
    return (d["type"]=="disk" and not d["ro"] and not d["rm"] and not d.get("children")
        and not d.get("fstype") and not any(d.get("mountpoints") or [])
        and d["size"] >= 25*1024**3 and re.fullmatch(r"/dev/(sd[a-z]+|vd[a-z]+|nvme\d+n\d+)",d["name"]) is not None)
def validate_disk(path):
    d = next((x for x in disks() if x["name"]==path),None)
    if not d or not eligible(d):
        raise RuntimeError("Only an empty, unmounted, non-removable disk of at least 25 GiB is supported.")
    if json.loads(output("wipefs","--json","--no-act",path)).get("signatures"):
        raise RuntimeError("Disk contains an existing filesystem or partition signature.")
    return d
def main():
    if os.geteuid()!=0: raise RuntimeError("Administrator rights required.")
    lock=open("/run/frameos-install.lock","w")
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    if "boot=casper" not in pathlib.Path("/proc/cmdline").read_text().split(): raise RuntimeError("Live session required.")
    if not pathlib.Path(IMAGE).is_file(): raise RuntimeError("Installation image missing.")
    if not pathlib.Path("/sys/firmware/efi").is_dir(): raise RuntimeError("This preview requires UEFI.")
    sb=sp.run(["mokutil","--sb-state"],capture_output=True,text=True)
    if "SecureBoot disabled" not in sb.stdout: raise RuntimeError("Disable Secure Boot for this unsigned preview.")
    data=json.loads(sys.stdin.readline())
    disk=data["disk"]; user=data["user"]; host=data["host"]; password=data["password"]
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,30}",user) or user in ("root","frameos"): raise RuntimeError("Invalid username.")
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9-]{0,62}",host) or host.endswith("-"): raise RuntimeError("Invalid hostname.")
    if len(password)<8 or any(c in password for c in "\n\r:"): raise RuntimeError("Invalid password.")
    locale=data["locale"]; zone=data["zone"]; keyboard=data["keyboard"]
    if locale not in ("en_US.UTF-8","pl_PL.UTF-8") or keyboard not in ("us","pl") or zone not in ("Europe/Warsaw","Etc/UTC"): raise RuntimeError("Unsupported regional settings.")
    d=validate_disk(disk)
    if data["confirm"]!="ERASE "+disk or data["size"]!=d["size"]: raise RuntimeError("Disk confirmation mismatch.")
    # Pin device identity and recheck immediately before destructive operation.
    st=os.stat(disk)
    validate_disk(disk)
    if os.stat(disk).st_rdev!=st.st_rdev: raise RuntimeError("Disk changed.")
    root=tempfile.mkdtemp(prefix="frameos-target-",dir="/mnt")
    mounted=[]
    def mount(source,dest,*opts):
        run("mount",*opts,source,dest); mounted.append(dest)
    def ch(*args,**kw): return run("chroot",root,*args,**kw)
    def write(path,content): pathlib.Path(root+path).write_text(content)
    try:
        print("Partitioning confirmed empty disk",flush=True)
        run("parted","-s",disk,"mklabel","gpt","mkpart","ESP","fat32","1MiB","513MiB","set","1","esp","on","mkpart","primary","ext4","513MiB","100%")
        run("udevadm","settle")
        p=disk+("p" if disk[-1].isdigit() else "")
        for _ in range(30):
            if os.path.exists(p+"1") and os.path.exists(p+"2"): break
            time.sleep(1)
        run("mkfs.fat","-F","32",p+"1")
        run("mkfs.ext4","-F",p+"2")
        mount(p+"2",root)
        print("Extracting system",flush=True)
        run("unsquashfs","-f","-no-progress","-d",root,IMAGE)
        os.makedirs(root+"/boot/efi",exist_ok=True)
        mount(p+"1",root+"/boot/efi")
        for path in ("/dev","/proc","/sys"):
            mount(path,root+path,"--rbind")
            run("mount","--make-rslave",root+path)
        mount("tmpfs",root+"/run","-t","tmpfs")
        write("/etc/fstab",f"UUID={output('blkid','-s','UUID','-o','value',p+'2')} / ext4 defaults 0 1\nUUID={output('blkid','-s','UUID','-o','value',p+'1')} /boot/efi vfat umask=0077 0 2\n")
        write("/etc/hostname",host+"\n")
        write("/etc/hosts","127.0.0.1 localhost\n127.0.1.1 "+host+"\n::1 localhost ip6-localhost ip6-loopback\n")
        write("/etc/locale.gen",locale+" UTF-8\n")
        ch("locale-gen")
        ch("update-locale","LANG="+locale)
        os.unlink(root+"/etc/localtime") if os.path.lexists(root+"/etc/localtime") else None
        os.symlink("/usr/share/zoneinfo/"+zone,root+"/etc/localtime")
        write("/etc/timezone",zone+"\n")
        write("/etc/default/keyboard",'XKBMODEL="pc105"\nXKBLAYOUT="'+keyboard+'"\nXKBVARIANT=""\nXKBOPTIONS=""\n')
        ch("useradd","-m","-s","/bin/bash","-G","sudo,adm",user)
        ch("chpasswd",input=user+":"+password+"\n",text=True)
        ch("passwd","-l","root")
        write("/etc/machine-id","")
        ch("systemd-machine-id-setup")
        print("Removing live components",flush=True)
        write("/usr/sbin/policy-rc.d","#!/bin/sh\nexit 101\n")
        os.chmod(root+"/usr/sbin/policy-rc.d",0o755)
        ch("apt-get","-y","purge","casper",env=dict(os.environ,DEBIAN_FRONTEND="noninteractive"))
        os.unlink(root+"/usr/sbin/policy-rc.d")
        for path in ("/etc/xdg/autostart/frameos-welcome.desktop","/etc/xdg/autostart/frameos-safe-desktop.desktop","/usr/share/applications/frameos-installer.desktop","/usr/share/applications/frameos-welcome.desktop","/usr/local/bin/frameos-install","/usr/local/bin/frameos-welcome","/usr/local/bin/frameos-installer-ui","/usr/local/lib/frameos/install-target.py"):
            pathlib.Path(root+path).unlink(missing_ok=True)
        print("Configuring bootloader",flush=True)
        ch("update-initramfs","-u","-k","all")
        ch("grub-install","--target=x86_64-efi","--efi-directory=/boot/efi","--bootloader-id=FrameOS","--no-nvram","--removable")
        ch("update-grub")
        if not pathlib.Path(root+"/boot/efi/EFI/BOOT/BOOTX64.EFI").is_file(): raise RuntimeError("EFI bootloader missing.")
        run("sync")
    finally:
        for dest in reversed(mounted):
            sp.run(["umount","-R",dest],check=False)
        try: os.rmdir(root)
        except OSError: pass
    print("Installation complete. Shut down and remove the ISO.",flush=True)
if __name__=="__main__":
    try: main()
    except Exception as e:
        print("ERROR:",str(e),flush=True); sys.exit(1)
