"""Behaviour and regression tests run inside the actual vendored Berry VM."""
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
game.seed=12345 game.start(false) game.obstacles=[]
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
game.seed=222 game.start(false)
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
game.new_match(false) game.seed=123 game.start(false)
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
game.seed=game.match_seed game.start(false) course=json.dump(game.obstacles)
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
game.seed=game.match_seed game.start(false)
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
        for key in ['start_speed','difficulty','switch_score','type_randomness','distance_randomness','matrix']:
            self.assertNotIn('# @config '+key+' ',SCRIPT)
        self.assertNotIn('self.start(true)',SCRIPT)

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
