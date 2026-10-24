#!/usr/bin/env python3
"""Export exact game-renderer frames and enlarged PNGs using only the Python standard library."""
import argparse
import json
import pathlib
import struct
import zlib
from run_checks import ROOT, run

NAMES = ['Grassland', 'Desert', 'Jungle', 'Neon City', 'Snow Ice', 'Volcano',
         'Moon Base', 'Storm Night', 'Crystal', 'Matrix']

def write_png(path, rows, scale=1):
    width=len(rows[0]);height=len(rows)
    raw=b''.join(b'\0'+b''.join(bytes.fromhex(c)*scale for c in row) for row in rows for _ in range(scale))
    def chunk(kind,data):
        return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',width*scale,height*scale,8,2,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def frames(output):
    return [[ [data[(y*52+x)*6:(y*52+x+1)*6] for x in range(52)] for y in range(16)]
            for line in output.splitlines() if line.startswith('FRAME ') for data in [line[6:]]]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames',type=int,default=120,help='Profile this many animated frames per world')
    args=parser.parse_args()
    checks='''
import gc
game.mode="run" game.multiplayer=false game.y=0.0 game.vy=0.0 game.duck=false
game.best=1234 game.score=345 game.label="345" game.world_auto=false
for w:0..9
 game.fixed_world=w game.distance=0.0 game.stage=0 game.scene_ms=0 game.palette()
 game.obstacles=[[31.0,0,5,4],[45.0,1,5,3]]
 game.rain_step(1800)
 game.scene_ms=1800
 game.draw() dump_frame()
 var peak=0 var time0=wall_us()
 for f:0..FRAMES-1
  game.rain_step(25)
  game.distance+=0.75 game.travel=(game.travel+0.75)%52 game.scene_ms+=25 game.ticks+=1
  var before=instructions()
  game.draw()
  peak=max(peak,instructions()-before)
 end
 var elapsed=wall_us()-time0
 gc.collect()
 print("PROFILE",w+1,peak,elapsed,heap_bytes())
end
'''.replace('FRAMES',str(args.frames))
    output=run((ROOT/'dino_runner.be').read_text(),checks)
    pictures=frames(output)
    dest=ROOT/'previews';dest.mkdir(exist_ok=True)
    contact=[['080B10']*108 for _ in range(92)]
    for i,rows in enumerate(pictures):
        stem=f'{i+1:02d}-{NAMES[i].lower().replace(" ","-")}'
        write_png(dest/(stem+'-52x16.png'),rows)
        write_png(dest/(stem+'.png'),rows,12)
        x0=(i%2)*54+1;y0=(i//2)*18+1
        for y,row in enumerate(rows):contact[y0+y][x0:x0+52]=row
    write_png(dest/'contact-sheet.png',contact,8)
    profiles=[]
    for line in output.splitlines():
        if line.startswith('PROFILE '):
            _,world,ins,us,heap=line.split()
            profiles.append({'world':int(world),'name':NAMES[int(world)-1],
                             'peak_draw_instructions':int(ins),'mean_draw_us_host':int(us)/args.frames,
                             'vm_heap_bytes_after_gc':int(heap)})
    (dest/'profile.json').write_text(json.dumps({'frames_per_world':args.frames,
        'environment':'Vendored AWTRIX Berry VM, native raster boundary mocks; host timings are not TC002 timings.',
        'worlds':profiles},indent=2)+'\n')
    for item in profiles:
        print(f'{item["world"]:02d} {item["name"]}: {item["peak_draw_instructions"]} instructions, '
              f'{item["mean_draw_us_host"]:.1f} us/frame on host, {item["vm_heap_bytes_after_gc"]} heap bytes')
    print('Wrote ten native frames, ten nearest-neighbour enlargements, contact sheet and profile.json')

if __name__=='__main__':main()
