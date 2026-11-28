#!/usr/bin/python3
import sys,json,pathlib
allowed={"gaming","office","creative","media"}
chosen=sorted(set(sys.argv[1].split(",")) & allowed) if len(sys.argv)>1 else []
p=pathlib.Path("/etc/frameos")
p.mkdir(exist_ok=True)
(p/"selected-packs.json").write_text(json.dumps(chosen))
