#!/usr/bin/env python3
"""Build a test-only Berry host from an existing AWTRIX NG source checkout."""
import argparse, pathlib, subprocess
p=argparse.ArgumentParser();p.add_argument('awtrix',type=pathlib.Path);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];b=a.awtrix.resolve()/'lib/berry';out=root/'.build';out.mkdir(exist_ok=True)
cmd=['cc','-O2','-Wno-comment','-DBE_USE_PRECOMPILED_OBJECT=1','-I'+str(b),'-I'+str(b/'src'),'-I'+str(b/'generate'),str(root/'tools/berry_host.c')]
cmd += [str(x) for x in sorted((b/'src').glob('*.c'))]+[str(b/'default/be_modtab.c'),str(b/'default/be_port.c'),'-lm','-o',str(out/'berry-host')]
subprocess.run(cmd,check=True)
