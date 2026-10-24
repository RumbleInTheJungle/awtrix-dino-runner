#!/usr/bin/env python3
"""Run real Berry code against deterministic device mocks and export pixel frames."""
import argparse, pathlib, re, subprocess, tempfile, time, json
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(script, checks, defaults=None):
    prelude=(ROOT/'tests/device_mock.be').read_text()
    values={}
    for key,typ,tail in re.findall(r'^# @config (\w+) (\w+) (.*)$',script,re.M):
        value=re.search(r'default=("[^"]*"|\S+)',tail)
        if value:
            v=value[1]
            if v.startswith('#'):v='0x'+v[1:]
            elif typ=='select':v=json.dumps(v.strip('"'))
            values[key]=v
    values.update(defaults or {})
    prelude+='\n'+''.join(f'saved[{json.dumps(k)}] = {v}\n' for k,v in values.items())
    with tempfile.TemporaryDirectory() as d:
        p=pathlib.Path(d)
        (p/'mock.be').write_text(prelude)
        (p/'game.be').write_text(script.replace('import gamepad','var gamepad = test_gamepad'))
        (p/'checks.be').write_text(checks)
        result=subprocess.run([str(ROOT/'.build/berry-host'),str(p/'mock.be'),str(p/'game.be'),str(p/'checks.be')],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(str(result.returncode)+"\n"+result.stderr+result.stdout)
        return result.stdout
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--smoke',action='store_true');a=p.parse_args()
    script=(ROOT/'dino_runner.be').read_text()
    print(run(script,'game.setup()\ngame.on_show()\ngame.draw()\nprint("SMOKE OK")\n'))
