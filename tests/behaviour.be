import json
import gc
var passed = 0
def check(condition, name)
  if !condition raise "test_failure", name end
  passed += 1
end
def tick(ms)
  clock_ms += ms
  game.step()
end
def release_all()
  pad_masks=[0,0] pad_dirs=[nil,nil] game.local_pressed=false
  tick(25)
end
def press(slot,key)
  release_all()
  pad_masks[slot-1]=test_gamepad.bit(key)
  tick(25)
  release_all()
end
check(game.initial_speed==30 && game.difficulty==5 && game.switch_score==500,"fixed rules")
check(game.type_randomness==100 && game.distance_randomness==100,"fixed randomness")
check(game.mode=="menu","on-demand menu")
game.setup() game.on_show() tick(100000)
check(game.mode=="menu","no idle demo")
game.menu_index=0
# Physical clock can start a solo run.
release_all() game.on_button_event("select","press") game.on_button_event("select","release")
check(game.mode=="ready" && !game.multiplayer,"solo select")
release_all() game.on_button_event("select","press") game.on_button_event("select","release")
check(game.mode=="countdown" && game.player==0,"clock ready confirmation")
for i:0..119 tick(25) end
check(game.mode=="run" && game.score==0,"three second countdown")
release_all()
game.on_button_event("select","press")
check(game.vy>0,"clock jump")
game.on_button_event("select","release")
# Pause freezes the simulation and animation time.
game.pause()
var frozen=game.scene_ms var dist=game.distance var rain=game.drops[0][0]
for i:0..19 tick(100) game.draw() end
check(game.scene_ms==frozen && game.distance==dist && game.drops[0][0]==rain,"pause freezes scene")
game.action("a",0)
check(game.mode=="run","explicit resume")
# Course reset and independent visual RNG.
game.multiplayer=true game.separate=false game.new_match(false)
game.seed=game.match_seed game.start()
var course=json.dump(game.obstacles)
for i:0..50 game.rain_random(10) end
game.score=321 game.finish_run()
check(game.mode=="ready" && game.logical==1,"second player handover")
game.seed=game.match_seed game.start()
check(json.dump(game.obstacles)==course && game.speed==30,"same course and speed")
game.turn=1 game.draw()
check(game.tint==0xFF3355,"P2 default colour")
game.score=400 game.finish_run()
check(game.mode=="initials" && game.pending==0,"initials delayed until both runs")
game.initials=[0,1,2] game.letter=2 game.action("a",0)
check(game.board[0][0]=="ABC" && game.board[0][1]==321,"first initials saved")
game.initials=[23,24,25] game.letter=2 game.action("a",0)
check(game.mode=="results" && game.board[0][0]=="XYZ","second initials and ranking")
game.action("a",0)
check(game.first==1 && game.logical==1,"rematch reverses order")
# Older equal scores retain priority; bounded top five.
game.board=[]
for v:1..6 game.add_record("AAA",v*100) end
game.add_record("OLD",600)
check(size(game.board)==5 && game.board[0][0]=="AAA" && game.board[1][0]=="OLD","top five and stable ties")
check(!game.qualifies(200) && !game.qualifies(0),"qualifying cutoff")
check(saved["leaderboard"][0][1]==600,"persistent leaderboard")
# No score on hide/quit.
var board_before=json.dump(game.board)
game.score=99999 game.on_hide()
check(json.dump(game.board)==board_before && !claims[0] && !claims[1],"abandoned run excluded")
# Gamepad loss and slot reordering require explicit confirmation.
game.on_show() pad_names=["PAD-A","PAD-B"] release_all()
game.multiplayer=true game.separate=true game.new_match(false)
press(2,"A") check(game.mode=="ready","wrong player cannot start")
press(1,"A") check(game.mode=="countdown","active player starts")
for i:0..119 tick(25) end
check(game.mode=="run","separate countdown")
pad_names=["PAD-B",""] tick(25)
check(game.mode=="pause" && game.recover,"slot change pauses")
var frozen2=game.scene_ms
tick(100) check(game.scene_ms==frozen2,"recovery freezes animation")
press(1,"A") check(game.mode=="run" && !game.recover,"controller confirmation resumes")
# A held through countdown cannot cause the first jump.
game.new_match(false) release_all() pad_masks=[1,0] tick(25)
for i:0..120 tick(25) end
check(game.y==0 && game.mode=="run","countdown input release gate")
release_all()
# Every 500 points increases speed once; worlds every 1000.
game.obstacles=[] game.distance=499.9 game.score=499 game.stage=0 game.speed=30
game.physics()
check(game.stage==1 && math.abs(game.speed-31.5)<0.001,"500px speed increase")
game.distance=999.9 game.score=999 game.physics()
check(game.stage==2 && math.abs(game.speed-33.075)<0.001 && game.next_world==1,"1000px world milestone")
check(size(messages)==0,"quiet logging by default")
saved["debug"]=true game.distance=1499.9 game.physics()
check(size(messages)==1,"optional stage debug")
saved["debug"]=false
# Render all worlds in both stage variants and logical colours.
for w:0..9
  for night:0..1
    game.world_auto=false game.fixed_world=w game.distance=0.0 game.stage=night game.palette()
    for player:0..1
      game.logical=player game.mode="run" game.draw()
      check(game.matrix==(w==9),"matrix world selection")
      check(game.tint==(w==9?0x66FF88:(player==0?0x3399FF:0xFF3355)),"world player colour")
    end
  end
end
# Render exact bytes before and after elapsed paused wall time.
game.world_auto=false game.fixed_world=9 game.distance=0.0 game.palette()
game.mode="pause" game.draw() dump_frame()
for i:0..99 tick(100) end
game.draw() dump_frame()
# Settings / menu states all draw within the native frame.
for mode:["menu","controls","ready","countdown","pause","scores","initials","results"]
 game.mode=mode game.menu_index=0 game.pending=0 game.completed=[0] game.draw()
end
game.quit()
check(closed && !claims[0] && !claims[1],"quit closes and releases")
print("PASS",passed)
gc.collect()
print("HEAP",gc.allocated())
