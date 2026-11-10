"""Behaviour and regression tests run inside the actual vendored Berry VM."""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from urllib.error import HTTPError

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from run_checks import run
import install

SCRIPT = (ROOT/'dino_runner.be').read_text()

def original():
    if (ROOT/'original.be').exists():
        return (ROOT/'original.be').read_text()
    first = subprocess.check_output(['git', 'rev-list', '--max-parents=0', 'HEAD'], cwd=ROOT, text=True).strip()
    return subprocess.check_output(['git', 'show', first+':dino_runner.be'], cwd=ROOT, text=True)

class GameTests(unittest.TestCase):
    def test_behaviour(self):
        out = run(SCRIPT, (ROOT/'tests/behaviour.be').read_text())
        frames = [s for s in out.splitlines() if s.startswith('FRAME ')]
        self.assertEqual(len(frames), 2)
        self.assertEqual(frames[0], frames[1], 'Paused frame changed')
        self.assertIn('PASS 113', out)

    def test_physics_matches_original(self):
        trace = '''
import json
game.seed=12345 game.start() game.obstacles=[]
for i:0..2399
  if i%60==0 game.launch() end
  game.jump_held=i%60<22
  clock_ms+=25
  game.physics()
  if i%10==0
    print(json.dump([game.score,game.stage,game.speed,game.y,game.vy,game.travel]))
  end
end
'''
        defaults = {'start_speed':'30', 'difficulty':'5', 'switch_score':'500',
                    'type_randomness':'100', 'distance_randomness':'100', 'sounds':'false'}
        # Stage logging is intentionally quieter in the new version.
        old = run(original(), trace, defaults)
        new = run(SCRIPT, trace, defaults)
        self.assertEqual(old, new)

    def test_obstacle_generation_and_collision_match(self):
        trace = '''
import json
game.seed=222 game.start()
print(json.dump(game.obstacles))
for i:0..799
  if game.mode=="run"
    clock_ms+=25 game.physics()
    print(json.dump([game.score,game.y,game.mode=="run",game.obstacles]))
  end
end
'''
        settings = {'start_speed':'30', 'difficulty':'5', 'switch_score':'500',
                    'type_randomness':'100', 'distance_randomness':'100', 'sounds':'false'}
        self.assertEqual(run(original(),trace,settings), run(SCRIPT,trace,settings))

    def test_dino_sprite_geometry_unchanged(self):
        old = original()
        def sprite(source):
            a=source.index('    var yy = 14 - round(self.y)',source.index('  def draw()'))
            b=source.index('    end\n',source.index('      pixel(6 + foot',a))+8
            return source[a:b]
        self.assertEqual(sprite(old),sprite(SCRIPT))

    def test_migrations_reset_and_saved_board(self):
        checks = '''
if game.world_auto || game.fixed_world!=9 raise "test", "matrix migration" end
if size(game.board)!=0 || saved["best"]!=0 raise "test", "fresh leaderboard" end
if saved["world_schema"]!=1 || saved["score_schema"]!=1 raise "test", "migration markers" end
'''
        run(SCRIPT,checks,{'matrix':'true','best':'1234'})
        run(SCRIPT,'''if size(game.board)!=2 || game.board[0][0]!="AAA" raise "test","persisted board" end''',
            {'score_schema':'1','leaderboard':'[["BBB",100],["AAA",500]]'})
        run(SCRIPT,'''if size(game.board)!=0 || saved["reset_best"] raise "test","reset" end''',
            {'score_schema':'1','leaderboard':'[["AAA",500]]','reset_best':'true'})
        run(SCRIPT,'''if size(game.board)!=0 raise "test","bad store" end''',
            {'score_schema':'1','leaderboard':'[nil,[],["AAA","bad"],["AA",100]]'})

    def test_animation_and_obstacle_skin_separation(self):
        run(SCRIPT, '''
import json
game.new_match(false) game.seed=123 game.start()
var before=json.dump(game.obstacles) var seed=game.seed
for w:0..9
 game.world_auto=false game.fixed_world=w game.stage=0 game.distance=0.0 game.palette()
 for frame:0..19
  game.scene_ms+=25 game.draw()
 end
end
if before!=json.dump(game.obstacles) || seed!=game.seed raise "test","renderer changed gameplay" end
''')

    def test_input_release_and_direction_edges(self):
        run(SCRIPT, '''
game.on_show() game.step()
pad_dirs=[ [1,0],nil ] game.step()
if game.menu_index!=1 raise "test","right edge" end
game.step()
if game.menu_index!=1 raise "test","held repeats" end
pad_dirs=[nil,nil] game.step()
pad_dirs=[[1,0],nil] game.step()
if game.menu_index!=2 raise "test","second edge lost" end
''')

    def test_pad_loss_during_countdown_restarts_countdown(self):
        run(SCRIPT, '''
import json
def tick(ms) clock_ms+=ms game.step() end
def release() pad_masks=[0,0] tick(25) end
def press(slot) release() pad_masks[slot-1]=1 tick(25) release() end
game.setup() game.on_show()
pad_names=["PAD-A","PAD-B"] release()
game.multiplayer=true game.separate=true game.new_match(false)
press(1)
for i:0..119 tick(25) end
var course=nil
game.seed=game.match_seed game.start() course=json.dump(game.obstacles)
# P1 crashes on an obstacle at the dino.
game.obstacles[0][0]=8.0 game.physics()
if game.mode!="ready" || game.logical!=1 raise "test","P2 handover" end
press(2)
if game.mode!="countdown" raise "test","P2 countdown" end
pad_names=["PAD-A",""] tick(25)
if game.mode!="pause" || !game.recover raise "test","countdown pad loss pauses" end
game.draw()
pad_names=["PAD-A","PAD-B"] release()
press(2)
if game.mode!="countdown" || game.recover raise "test","confirmation restarts countdown" end
for i:0..118 tick(25) end
if game.mode!="run" raise "test","countdown completes" end
if game.score!=0 || game.distance>1.0 || game.logical!=1 raise "test","fresh P2 run" end
for i:0..3 tick(25) end
if game.mode!="run" raise "test","P2 survives start" end
game.seed=game.match_seed game.start()
if json.dump(game.obstacles)!=course raise "test","same course" end
''')

    def test_hiding_pauses_run_and_restarts_countdown(self):
        run(SCRIPT, '''
def tick(ms) clock_ms+=ms game.step() end
game.setup() game.on_show()
game.multiplayer=false game.new_match(false) game.action("a",0)
if game.mode!="countdown" raise "test","countdown" end
tick(2500)
game.on_hide() clock_ms+=10000 game.on_show()
for i:0..80 tick(25) end
if game.mode!="countdown" raise "test","hidden countdown restarts" end
for i:0..40 tick(25) end
if game.mode!="run" raise "test","countdown completes" end
game.obstacles=[] for i:0..9 tick(25) end
var dist=game.distance
game.on_button_event("select","press")
game.on_hide() clock_ms+=10000 game.on_show()
for i:0..9 tick(25) end
if game.mode!="pause" || game.distance!=dist raise "test","hidden run pauses" end
if game.local_pressed raise "test","held clock button cleared" end
if game.gated raise "test","input unblocked after return" end
game.action("a",0)
if game.mode!="run" raise "test","resume after return" end
''')

    def test_world_tour_visits_every_world_without_ending(self):
        run(SCRIPT, '''
var played=[]
game.audio=true
sound.effect=def(tune) played.push(tune) end
def tick(ms) clock_ms+=ms game.step() end
game.setup() game.on_show()
game.world_auto=false game.fixed_world=4
var board=str(game.board) var best=game.best
game.mode="menu" game.menu_index=2
game.action("right",0)
if game.menu_index!=3 raise "test","worlds entry" end
game.draw()
game.action("a",0)
if !game.tour || game.mode!="run" || !game.world_auto raise "test","tour starts" end
game.gated=false
var speed=game.speed
var seen={}
for s:0..19
  # One phase per five seconds: day, then night or the late phase, then the next world.
  for i:0..199
    tick(25)
    if game.mode!="run" raise "test","tour never ends "+str(s) end
  end
  game.draw()
  seen[str(game.stage/2%10)+"/"+str(game.stage%2)]=true
end
if size(seen)!=20 raise "test","all worlds day and night: "+str(size(seen)) end
if game.speed!=speed raise "test","tour keeps its speed" end
if size(played)!=0 raise "test","tour is silent" end
if str(game.board)!=board || game.best!=best raise "test","tour saves nothing" end
# A hidden tour pauses; B returns to the menu and restores the world setting.
game.on_hide() game.on_show()
if game.mode!="pause" raise "test","tour pauses when hidden" end
game.action("a",0)
if game.mode!="run" || !game.tour raise "test","tour resumes" end
game.action("a",0)
if game.mode!="menu" || game.tour || game.world_auto || game.fixed_world!=4 raise "test","tour ends on a button" end
if game.stage!=0 raise "test","menu back on a fresh stage" end
''')

    def test_mqtt_reports_under_the_clocks_prefix(self):
        run(SCRIPT, '''
import json
def tick(ms) clock_ms+=ms game.step() end
def states() var r=[] for p:published if p[0]==game.mqtt_root+"/state" r.push(json.load(p[1])) end end return r end
def events() var r=[] for p:published if p[0]==game.mqtt_root+"/event" r.push(json.load(p[1])["event"]) end end return r end
game.setup()
# No prefix set: the clock's uid is used, read from the local API.
if size(http_calls)!=1 || http_calls[0][0]!="http://127.0.0.1/api/v1/system" raise "test","asks for prefix" end
http_calls[0][1]("\\"mqttPrefix\\":\\"\\",\\"mqttTls\\":false", 200)
if size(http_calls)!=2 || http_calls[1][0]!="http://127.0.0.1/api/v1/device" raise "test","asks for uid" end
http_calls[1][1]("\\"uid\\":\\"ccc4b2779912\\",\\"hostname\\"", 200)
if game.mqtt_root!="ccc4b2779912/dinorunner" raise "test","uid root "+game.mqtt_root end
published=[]
game.on_show() tick(25)
var s=states()
if size(s)!=1 || s[0]["mode"]!="menu" raise "test","menu state" end
for i:0..39 tick(25) end
if size(states())!=1 raise "test","no repeats while nothing changes" end
# A solo run: countdown, run, night, crash, results.
game.world_auto=false game.fixed_world=0 game.best=99999
game.multiplayer=false game.new_match(false) game.action("a",0) tick(25)
s=states()[-1]
if s["mode"]!="countdown" || s["room"]!="game" || !s.contains("enter") raise "test","countdown enters "+str(s) end
for i:0..130 tick(25) end
s=states()[-1]
if s["mode"]!="run" || s["world"]!=1 || s["phase"]!="day" || s["dark"] || s["color"]!="#FFD890" raise "test","run day "+str(s) end
if s.contains("enter") raise "test","enter only once" end
if events()!=["roar"] raise "test","roar event "+str(events()) end
game.obstacles=[[200.0,0,5,4],[300.0,0,5,4]]
game.distance=499.9 game.score=499 for i:0..3 tick(25) end
s=states()[-1]
if s["phase"]!="night" || !s["dark"] || s["color"]!="#3050C0" raise "test","night "+str(s) end
game.obstacles=[[6.0,0,5,4]] tick(25) tick(25)
if events()[-1]!="crash" raise "test","crash event" end
s=states()[-1]
if s["mode"]!="results" || s["score"]!=game.score || s["room"]!="normal" || !s.contains("leave") raise "test","results "+str(s) end
var before=size(published)
game.on_hide()
if states()[-1]["mode"]!="off" || states()[-1].contains("leave") raise "test","off when hidden" end
if size(published)!=before+1 raise "test","one message on hide" end
# Two players: the room stays dimmed between turns.
game.on_show() tick(25)
game.multiplayer=true game.separate=false game.new_match(false) tick(25)
if states()[-1]["room"]!="normal" raise "test","first ready is not yet the game" end
game.action("a",0) for i:0..130 tick(25) end
game.obstacles=[[6.0,0,5,4]] tick(25) tick(25)
s=states()[-1]
if s["mode"]!="ready" || s["room"]!="game" || s.contains("enter") || s.contains("leave") raise "test","second turn keeps the room "+str(s) end
game.multiplayer=false
# Permanent night worlds are always dark and report a late phase.
game.on_show() game.fixed_world=3 game.start() game.stage=1 game.palette() tick(25)
s=states()[-1]
if s["phase"]!="late" || !s["dark"] || s["world"]!=4 raise "test","late "+str(s) end
# A prefix set on the clock wins; a refused request keeps the fallback.
http_calls=[]
game.mqtt_root="dinorunner" game.setup()
http_calls[0][1]("\\"mqttPrefix\\":\\"trix\\",", 200)
if game.mqtt_root!="trix/dinorunner" || size(http_calls)!=1 raise "test","prefix root" end
http_calls=[]
game.mqtt_root="dinorunner" game.setup()
http_calls[0][1](nil, 401)
if game.mqtt_root!="dinorunner" || size(http_calls)!=1 raise "test","login fallback" end
''')

    def test_results_fanfare_only_for_new_number_one(self):
        run(SCRIPT, '''
var played=[]
game.audio=true
sound.effect=def(tune) for k:game.tunes.keys() if game.tunes[k]==tune played.push(k) end end end
def finish_match(multi,a,b)
  game.multiplayer=multi game.separate=false game.new_match(false)
  played=[]
  game.score=a game.finish_run()
  if multi game.score=b game.finish_run() end
  while game.mode=="initials"
    game.initials=[0,0,0] game.letter=2 game.action("a",0)
  end
  if game.mode!="results" raise "test","results reached" end
  return played.find("record")!=nil
end
game.board=[] game.add_record("TOP",500)
for v:[100,200,300,400] game.add_record("LOW",v) end
if finish_match(false,300,0) raise "test","no fanfare below #1" end
if finish_match(false,450,0) raise "test","no fanfare for top five but not #1" end
if finish_match(false,500,0) raise "test","no fanfare for tying #1" end
if !finish_match(false,501,0) raise "test","fanfare for new #1" end
if game.best!=501 raise "test","new best saved" end
if finish_match(true,200,300) raise "test","no multiplayer fanfare below #1" end
if !finish_match(true,100,700) raise "test","fanfare when second player takes #1" end
''')

    def test_led_floor_keeps_layers_visible_and_ordered(self):
        run(SCRIPT, '''
def peak(c) return max((c>>16)&255, max((c>>8)&255, c&255)) end
for w:0..9
  for stage:0..1
    game.world_auto=false game.fixed_world=w game.stage=stage game.distance=0.0 game.palette()
    var c=game.colors
    var fl=(stage==1 && game.has_night[w]) ? [0,40,50,64,0,40] : [0,56,72,92,0,56]
    if w!=9
      if peak(c[1])<fl[1] || peak(c[2])<fl[2] || peak(c[3])<fl[3] || peak(c[5])<fl[5] raise "test","floor "+str(w) end
    end
    if peak(c[1])>peak(c[2]) || peak(c[2])>peak(c[3]) raise "test","layer order "+str(w) end
    if peak(c[3])>=peak(c[6]) raise "test","decoration brighter than hazards "+str(w) end
  end
end
# Matrix keeps its original dark backdrop below the rain.
game.fixed_world=9 game.stage=0 game.palette()
if game.colors[1]!=0x001307 raise "test","matrix exempt" end
''')

    def test_night_is_distinct_and_fades_through_dusk(self):
        run(SCRIPT, '''
def peak(c) return max((c>>16)&255, max((c>>8)&255, c&255)) end
def look(w, stage)
  game.world_auto=false game.fixed_world=w game.stage=stage game.distance=0.0 game.palette()
  return game.colors
end
for w:0..9
  var day=look(w,0)
  var late=look(w,1)
  # Hazards and the dino never change with the time of day.
  if day[6]!=late[6] || day[7]!=late[7] raise "test","hazards change "+str(w) end
  if game.has_night[w]
    # Moonlit scenery: far, mid and near visibly darker and blue-tinted.
    for i:1..3
      if peak(day[i])-peak(late[i])<12 raise "test","night too bright "+str(w)+"/"+str(i) end
      if (late[i]&255)<((late[i]>>16)&255) raise "test","night not cool "+str(w)+"/"+str(i) end
    end
    # The moon base sky is already black by day.
    if peak(late[0])>max(10,peak(day[0])/2) raise "test","night sky "+str(w) end
  else
    # Permanent night worlds keep their scenery and shift only accents and sky.
    for i:1..5 if day[i]!=late[i] raise "test","late scenery "+str(w) end end
    var moved=0
    for i:8..11 if day[i]!=late[i] moved+=1 end end
    if w!=9 && moved==0 raise "test","late phase invisible "+str(w) end
  end
end
# Day to night in one world: a slow fade with a warm horizon band halfway.
game.fixed_world=0 game.stage=0 game.distance=0.0 game.palette()
game.distance=500.0 game.scene_ms=10000 game.stage=1 game.palette()
if game.fade_ms!=1500.0 || game.glow!=1 raise "test","dusk fade" end
game.scene_ms=10750 game.apply_palette()
if game.horizon==nil || size(game.horizon)!=6 raise "test","dusk band" end
game.scene_ms=11500 game.apply_palette()
if game.horizon!=nil raise "test","band gone after fade" end
# Back to day in the same world: dawn.
game.distance=1000.0 game.stage=2 game.palette()
if game.glow!=-1 raise "test","dawn" end
# A change of world keeps the quick cross-fade and no band; the moon has no dusk.
game.world_auto=true game.stage=2 game.palette()
if game.fade_ms!=500.0 || game.glow!=0 raise "test","world change fade" end
game.world_auto=false game.fixed_world=6 game.distance=0.0 game.stage=0 game.palette()
game.distance=500.0 game.stage=1 game.palette()
if game.glow!=0 raise "test","no dusk on the moon" end
# The countdown starts on a settled day palette without a band.
game.distance=0.0 game.stage=0 game.palette()
if game.horizon!=nil || game.glow!=0 raise "test","fresh run band" end
''')

    def test_egg_countdown_cracks_hatches_and_roars(self):
        run(SCRIPT, '''
import json
var played=[]
game.audio=true
sound.effect=def(tune) for k:game.tunes.keys() if game.tunes[k]==tune played.push(k) end end end
def tick(ms) clock_ms+=ms game.step() end
game.setup() game.on_show()
game.multiplayer=false game.new_match(false)
# A finished previous run must not show behind the countdown.
game.distance=1234.0 game.stage=3
game.action("a",0)
if game.mode!="countdown" || game.distance!=0.0 || game.stage!=0 raise "test","fresh world behind countdown" end
var course=json.dump(game.obstacles)
game.draw()
var t0=clock_ms
while clock_ms-t0<2975 tick(25) game.draw() end
if game.mode!="countdown" raise "test","still counting" end
if played!=["crack1","crack1","crack2"] raise "test","cracks on 3, 2 and 1: "+str(played) end
tick(25)
if game.mode!="run" || played[-1]!="crack3" raise "test","shell bursts at zero: "+str(played) end
if json.dump(game.obstacles)!=course raise "test","same course after countdown" end
for i:0..8 tick(25) end
if played.find("roar")!=nil raise "test","roar waits for the burst" end
tick(25)
if played.find("roar")==nil raise "test","roar a quarter second later: "+str(played) end
# The hatch is only an overlay: physics continues normally beneath it.
for i:0..27 tick(25) game.draw() end
if game.mode!="run" || game.y!=0.0 || game.score<20 raise "test","hatch does not affect the run" end
''')

    def test_audio_failure_warns_once(self):
        run(SCRIPT, '''
game.audio=true
test_gamepad.buttons=test_gamepad.buttons
sound.effect=def(tune) raise "audio_error","unavailable" end
game.play_event("small") game.play_event("small")
if game.audio || size(messages)!=1 raise "test","audio fallback" end
''')

    def test_solo_after_separate_multiplayer_and_clock_initials(self):
        run(SCRIPT, '''
game.separate=true game.multiplayer=false game.new_match(false)
game.action("a",0)
if game.mode!="countdown" raise "test","solo inherited controller restriction" end
game.mode="initials" game.completed=[0] game.pending=0 game.initials=[0,0,0] game.letter=1
game.gated=false
game.on_button_event("left","press") game.on_button_event("left","long") game.on_button_event("left","release")
if game.letter!=0 || game.initials[1]!=0 raise "test","clock initials back" end
game.gated=false
game.on_button_event("left","press") game.on_button_event("left","release")
if game.initials[0]!=25 raise "test","clock initials previous letter" end
''')

    def test_adaptive_effects_and_memory_bound(self):
        run(SCRIPT, '''
import gc
game.mode="run" game.obstacles=[] game.world_auto=false game.fixed_world=9 game.distance=0.0 game.palette()
var fake_time=0
now_ms=def() fake_time+=25 return fake_time end
game.draw()
if game.fx_budget!=100 raise "test","single slow draw ignored" end
game.draw() game.draw()
if game.fx_budget!=90 raise "test","sustained slow draws reduce effects" end
game.mode="pause" for i:0..9 game.draw() end
if game.fx_budget!=90 raise "test","paused fallback changed frame" end
now_ms=def() return clock_ms end
game.mode="run"
# Occasional spikes (one slow draw in ten) never reduce effects.
game.fx_budget=100 game.fx_strain=0 game.fx_calm=0
for i:0..99 game.adapt_effects(i%10==0) end
if game.fx_budget!=100 raise "test","isolated spikes ignored" end
# A long fast streak restores a step, capped at full effects.
game.fx_budget=80 game.fx_strain=0 game.fx_calm=0
for i:0..199 game.adapt_effects(false) end
if game.fx_budget!=90 raise "test","effects recover" end
for i:0..999 game.adapt_effects(false) end
if game.fx_budget!=100 raise "test","recovery capped" end
game.fx_budget=100
gc.collect() var before=heap_bytes()
for i:0..999
 game.scene_ms+=25 game.distance+=0.75 game.rain_step(25) game.draw()
end
gc.collect()
if heap_bytes()>before+4096 raise "test","renderer memory growth" end
''')

    def test_metadata_and_removed_settings(self):
        self.assertIn('# @ondemand\n', SCRIPT)
        for key in ['start_speed','difficulty','switch_score','type_randomness','distance_randomness','matrix',
                    'haze','haze_intensity','matrix_brightness']:
            self.assertNotIn('# @config '+key+' ',SCRIPT)
        for leftover in ['demo','autoplay','mist(']:
            self.assertNotIn(leftover,SCRIPT)

class InstallerTests(unittest.TestCase):
    def test_matrix_upgrade_and_backup(self):
        calls=[]
        def send(base,path,method='GET',body=None,content_type='application/json'):
            calls.append((path,method,body))
            if method=='GET':
                return {'fields':[{'key':'matrix','value':True}]} if path.endswith('/config') else 'original source'
            return {'ok':True,'error':None}
        with tempfile.TemporaryDirectory() as d:
            self.assertTrue(install.install('http://clock','dino',pathlib.Path(d),send))
            self.assertEqual((pathlib.Path(d)/'dino.be').read_text(),'original source')
        self.assertEqual(json.loads(calls[-1][2]),{'world_mode':'fixed','fixed_world':'10'})

    def test_sounds_upload_only_when_changed(self):
        calls=[]
        with tempfile.TemporaryDirectory() as d:
            sounds=pathlib.Path(d)
            (sounds/'roar.mp3').write_bytes(b'ID3fake-mp3')
            same=hashlib.sha256(b'ID3fake-mp3').hexdigest()
            def send(base,path,method='GET',body=None,content_type='application/json'):
                calls.append((path,method,content_type,body))
                if method=='GET':
                    return {'files':[{'name':'roar.mp3','sha256':held}]}
                return {'ok':True}
            held='0'*64
            self.assertEqual(install.sync_sounds('http://clock/','dino',send,sounds),['roar.mp3'])
            path,method,content_type,body=calls[-1]
            self.assertEqual((path,method),('/api/v1/apps/script/dino/sounds','POST'))
            self.assertTrue(content_type.startswith('multipart/form-data; boundary='))
            self.assertIn(b'filename="roar.mp3"',body)
            self.assertIn(b'ID3fake-mp3',body)
            held=same
            calls.clear()
            self.assertEqual(install.sync_sounds('http://clock','dino',send,sounds),[])
            self.assertEqual([c[1] for c in calls],['GET'])

    def test_shipped_sounds_are_small_mp3s_the_script_plays(self):
        for name in ['roar','crack1','crack2','crack3']:
            data=(ROOT/'sounds'/(name+'.mp3')).read_bytes()
            self.assertLess(len(data),16384)
            self.assertTrue(data[:3]==b'ID3' or (data[0]==0xFF and data[1]&0xE0==0xE0))
            self.assertIn('"%s": ["%s", '%(name,name),SCRIPT)

    def test_new_install_and_device_error(self):
        def missing(base,path,method='GET',body=None,content_type='application/json'):
            if method=='GET':raise HTTPError(base+path,404,'missing',{},None)
            return {'ok':True,'error':None}
        with tempfile.TemporaryDirectory() as d:
            self.assertFalse(install.install('http://clock','dino',pathlib.Path(d),missing))
        with self.assertRaises(RuntimeError):install.check_answer({'ok':True,'error':{'message':'compile failed'}})
        with self.assertRaises(ValueError):install.install('http://clock','bad/name',ROOT,missing)

if __name__=='__main__':
    unittest.main()
