# @name Dino Runner
# @desc Turn-based dinosaur runner with ten pixel worlds
# @version 0.1.0
# @display 52x16
# @ondemand
# @config world_mode select "World mode" options=auto,fixed default=auto group="Worlds"
# @config fixed_world select "Fixed world" options=1,2,3,4,5,6,7,8,9,10 default=1 group="Worlds" help="1 Grassland, 2 Desert, 3 Jungle, 4 City, 5 Ice, 6 Volcano, 7 Moon, 8 Storm, 9 Crystal, 10 Matrix"
# @config parallax_enabled bool "Scrolling scenery" default=true group="Worlds"
# @config parallax_intensity slider "Parallax intensity" default=100 min=0 max=100 unit=% group="Worlds"
# @config ambient_effects bool "Ambient effects" default=true group="Worlds"
# @config ambient_density slider "Ambient effect density" default=25 min=0 max=100 unit=% group="Worlds"
# @config p2_color color "P2 dino color" default=#FF3355 group="Players"
# @config debug bool "Debug logging" default=false group="Diagnostics"
# @config dino_color color "P1 / solo dino color" default=#3399FF group="Players"
# @config reset_best bool "Reset high scores (one shot)" default=false group="Scores"
# @config daylight color "Daylight color" default=#181E14 group="Worlds"
# @config haze bool "Moving haze" default=false group="Worlds"
# @config haze_intensity slider "Haze intensity (0–100%)" default=25 min=0 max=100 unit=% group="Worlds"
# @config matrix_brightness slider "Matrix rain brightness (0–100%)" default=40 min=0 max=100 unit=% group="Worlds"
# @config sounds bool "Game sounds" default=true group="Sound"
# @config sound_volume slider "Game sound volume (0–100%)" default=60 min=0 max=100 unit=% group="Sound"
# Native AWTRIX NG TC002 on-demand game, 52x16. No server or MQTT required.
# Active player: A jump/start/retry, B or D-pad down duck, START pause,
# SELECT quit. Clock: select jump/retry, right hold duck, left pause.

import gamepad
import math

class DinoRunner
  var mode, best, score, label, before, up_before, local_duck
  var y, vy, duck, obstacles, seed, ticks, last, accumulator, active
  var digits, travel, jump_until
  var tint, switch_score, difficulty, initial_speed, speed, distance, stage
  var demo, idle_since, bg, fg, gold, ground
  var type_randomness, distance_randomness, day_color, haze, haze_intensity
  var jump_held, local_jump, jump_age, jump_cut, stars, jump_gravity
  var matrix, matrix_brightness, drops, rain_seed
  var player, pad_label
  var audio, tunes, record_target, record_announced, match_record

  var logical, multiplayer, separate, first, order, turn, match_seed, scores, completed
  var board, pending, initials, letter, menu_index, rank, gated, recover, countdown_at
  var previous, up_previous, dx_previous, pad_names, local_pressed, scene_ms

  var worlds, world, next_world, old_colors, colors, transition_at, hills
  var parallax, parallax_intensity, ambient, density, fixed_world, world_auto
  var font, fx_budget, fx_strain, fx_calm, bindings, left_pending, resume_countdown
  var shades, shade_phase, rain_ramps, player_colors
  var bit_a, bit_b, bit_start, bit_select

  def init()
    self.font = {
      "A":[2,5,7,5,5],"B":[6,5,6,5,6],"C":[3,4,4,4,3],"D":[6,5,5,5,6],
      "E":[7,4,6,4,7],"F":[7,4,6,4,4],"G":[3,4,5,5,3],"H":[5,5,7,5,5],
      "I":[7,2,2,2,7],"J":[1,1,1,5,2],"K":[5,5,6,5,5],"L":[4,4,4,4,7],
      "M":[5,7,7,5,5],"N":[5,7,7,7,5],"O":[2,5,5,5,2],"P":[6,5,6,4,4],
      "Q":[2,5,5,3,1],"R":[6,5,6,5,5],"S":[3,4,2,1,6],"T":[7,2,2,2,2],
      "U":[5,5,5,5,7],"V":[5,5,5,5,2],"W":[5,5,7,7,5],"X":[5,5,2,5,5],
      "Y":[5,5,2,2,2],"Z":[7,1,2,4,7],":":[0,2,0,2,0],"!":[2,2,2,0,2],
      "<":[1,2,4,2,1],">":[4,2,1,2,4]," ":[0,0,0,0,0]}
    self.mode = "menu"
    self.multiplayer = store.get("last_multiplayer", false)
    self.separate = store.get("separate_controls", false)
    self.menu_index = self.multiplayer ? 1 : 0
    self.bindings = [1, 2]
    self.left_pending = false
    self.logical = 0
    self.first = 0
    self.scores = [0, 0]
    self.completed = []
    self.turn = 0
    self.rank = 0
    self.pending = 0
    self.previous = [0, 0]
    self.up_previous = [0, 0]
    self.dx_previous = [0, 0]
    self.pad_names = ["", ""]
    self.local_pressed = false
    self.gated = true
    self.recover = false
    self.resume_countdown = false
    self.scene_ms = 0
    self.countdown_at = 0
    self.match_seed = 1
    self.order = [0, 1]
    self.initials = [0, 0, 0]
    self.letter = 0
    self.audio = store.get("sounds") && sound.can("song")
    self.record_target = 0
    self.record_announced = false
    self.match_record = 0
    var volume = int(clamp(num(store.get("sound_volume"), 60), 0, 100))
    if volume == 0 self.audio = false end
    var prefix = "loop off\nvolume " + str(volume) + "\n"
    var blip = "inst blip wave=tri attack=6 decay=120 sustain=40 release=40 cutoff=2400 volume=90\n"
    self.tunes = {
      "small": {"song": prefix + "bpm 240\n" + blip + "blip: c5:1 e5:2"},
      "high": {"song": prefix + "bpm 240\n" + blip + "blip: c5:1 g5:1 c6:2"},
      "switch": {"song": prefix + "bpm 120\n" + blip + "blip: g5:1 r:1/2 c6:2"},
      "record": {"song": prefix + "bpm 220\n" + blip + "blip: c5:2 e5:2 g5:2 c6:4 r:2 a5:2 b5:2 c6:6"},
      "over": {"song": prefix + "bpm 120\n"
        + "inst hit wave=tri attack=3 decay=180 sustain=40 release=70 cutoff=1800 volume=90\n"
        + "inst fall wave=tri attack=3 decay=180 sustain=40 release=70 cutoff=1400 glide=600 vibrato=20/6/150 volume=90\n"
        + "hit: e5:1 c5:1 g4:1 @fall c4:1 ^g2:6"}
    }
    self.player = 1
    self.pad_label = "NO PAD"
    if store.get("world_schema", 0) != 1
      if store.get("matrix", false)
        store.set("world_mode", "fixed")
        store.set("fixed_world", "10")
      end
      store.set("world_schema", 1)
    end
    self.matrix = false
    self.matrix_brightness = int(clamp(num(store.get("matrix_brightness"),40),0,100))
    self.build_rain_ramps()
    # Settings and button masks are fixed for the session; read them once, not per frame.
    self.player_colors = [store.get("dino_color", 0x3399FF), store.get("p2_color", 0xFF3355)]
    self.bit_a = gamepad.bit("A")
    self.bit_b = gamepad.bit("B")
    self.bit_start = gamepad.bit("START")
    self.bit_select = gamepad.bit("SELECT")
    self.shades = []
    self.shade_phase = -1.0
    self.rain_seed = now_ms()%65521+17
    self.fx_budget = 100
    self.fx_strain = 0
    self.fx_calm = 0
    self.init_worlds()
    self.type_randomness = 100
    self.distance_randomness = 100
    self.day_color = store.get("daylight")
    self.haze = store.get("haze")
    self.haze_intensity = clamp(num(store.get("haze_intensity"), 25), 0, 100)
    self.local_jump = false
    self.jump_held = false
    self.jump_age = 0
    self.jump_cut = false
    self.jump_gravity = 24.0
    self.stars = [[22,1,7],[29,6,13],[35,2,19],[48,7,31],[18,7,43],[39,6,59]]
    self.tint = self.player_colors[self.logical]
    self.switch_score = 500
    self.difficulty = 5
    self.initial_speed = 30
    self.speed = self.initial_speed * 1.0
    self.distance = 0.0
    self.stage = 0
    self.demo = false
    self.idle_since = now_ms()
    self.palette()
    if store.get("score_schema", 0) != 1
      store.set("leaderboard", [])
      store.set("best", 0)
      store.set("score_schema", 1)
    end
    self.board = []
    var saved = store.get("leaderboard", [])
    if isinstance(saved, list)
      for row : saved
        if isinstance(row, list) && size(row) == 2 && type(row[0]) == "string" && size(row[0]) == 3 && type(row[1]) == "int" && row[1] > 0
          # Rebuild in memory only; loading must not rewrite the stored board.
          self.insert_record(row[0], row[1])
        end
      end
    end
    if store.get("reset_best", false)
      self.board = []
      store.set("leaderboard", [])
      store.set("reset_best", false)
    end
    self.best = size(self.board) > 0 ? self.board[0][1] : 0
    self.score = 0
    self.label = "0"
    self.before = 0
    self.up_before = false
    self.local_duck = false
    self.duck = false
    self.y = 0.0
    self.vy = 0.0
    self.ticks = 0
    self.travel = 0.0
    self.jump_until = 0
    self.seed = now_ms() % 65521 + 1
    self.reset_obstacles()
    self.last = now_ms()
    self.accumulator = 0
    self.active = false
    # Tiny 3x5 digits; each row is a three-bit mask.
    self.digits = [[7,5,5,5,7],[2,6,2,2,7],[7,1,7,4,7],
                   [7,1,7,1,7],[5,5,7,1,1],[7,4,7,1,7],
                   [7,4,7,5,7],[7,1,1,1,1],[7,5,7,5,7],
                   [7,5,7,1,7]]
  end

  def setup()
    var id = timer.every(25, / -> self.step())
    if id == nil
      raise "runtime_error", "No free game timer"
    end
  end

  def duration()
    return 20000
  end

  def on_show()
    self.active = true
    self.last = now_ms()
    self.gated = true
    # A countdown counts wall time, so restart it rather than letting it expire unseen.
    if self.mode == "countdown" self.countdown_at = self.last end
    rotation.pause()
  end

  def on_hide()
    self.active = false
    # Coming back mid-run should not drop the player straight into motion.
    if self.mode == "run" self.pause() end
    self.local_duck = false
    self.local_jump = false
    # A release event may never arrive while hidden; don't block input on return.
    self.local_pressed = false
    self.left_pending = false
    gamepad.release(self, 1)
    gamepad.release(self, 2)
    rotation.resume()
  end

  def random(n)
    self.seed = (self.seed * 75 + 74) % 65521
    return self.seed % n
  end

  def start(demo)
    self.mode = "run"
    self.demo = demo
    self.scene_ms = 0
    self.record_target = self.best
    self.record_announced = false
    if !demo rotation.pause() end
    self.distance = 0.0
    self.stage = 0
    self.speed = self.initial_speed * 1.0
    self.palette()
    self.score = 0
    self.label = "0"
    self.ticks = 0
    self.travel = 0.0
    self.jump_until = 0
    self.y = 0.0
    self.vy = 0.0
    self.duck = false
    self.local_duck = false
    self.reset_obstacles()
    self.accumulator = 0
    self.last = now_ms()
  end

  def jump()
    if self.demo || self.mode == "ready" || self.mode == "dead"
      self.start(false)
    elif self.mode == "run"
      # A slightly early second press waits for landing instead of being lost.
      self.jump_until = now_ms() + 300
      if self.y <= 0.0
        self.duck = false
        self.launch()
        self.jump_until = 0
      end
    end
  end







  # Logical players never depend on the firmware's mutable input slot numbers.
  def menu()
    self.mode = "menu"
    self.demo = false
    self.local_jump = false
    self.local_duck = false
    self.gated = true
    self.recover = false
    self.resume_countdown = false
    self.accumulator = 0
  end

  def quit()
    gamepad.release(self, 1)
    gamepad.release(self, 2)
    rotation.close()
  end

  def new_match(rematch)
    if rematch self.first = 1 - self.first else self.first = 0 end
    self.order = self.first == 0 ? [0, 1] : [1, 0]
    self.match_seed = now_ms() % 65521 + 1
    # The #1 score to beat for this match, before any of its initials are saved.
    self.match_record = self.best
    self.scores = [0, 0]
    self.completed = []
    self.turn = 0
    self.prepare_turn()
  end

  def prepare_turn()
    self.logical = self.multiplayer ? self.order[self.turn] : 0
    self.player = self.multiplayer && self.separate ? self.bindings[self.logical] : 1
    self.mode = "ready"
    self.gated = true
    self.recover = false
    self.resume_countdown = false
    self.palette()
  end

  def finish_run()
    self.scores[self.logical] = self.score
    self.completed.push(self.logical)
    self.play_event("over")
    self.gated = true
    if self.multiplayer && self.turn == 0
      self.turn = 1
      self.prepare_turn()
    else
      self.pending = 0
      self.next_initials()
    end
  end

  def qualifies(value)
    return value > 0 && (size(self.board) < 5 || value > self.board[4][1])
  end

  def next_initials()
    while self.pending < size(self.completed)
      var p = self.completed[self.pending]
      if self.qualifies(self.scores[p])
        self.initials = [0, 0, 0]
        self.letter = 0
        self.mode = "initials"
        self.gated = true
        return
      end
      self.pending += 1
    end
    self.mode = "results"
    # Fanfare only when this match took #1; an equal score ranks below the older one.
    for p : self.completed
      if self.scores[p] > self.match_record
        self.play_event("record")
        break
      end
    end
    self.menu_index = 0
    self.gated = true
  end

  def initials_text()
    var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var name = ""
    for c : self.initials name += alphabet[c..c] end
    return name
  end

  def add_record(name, value)
    self.insert_record(name, value)
    store.set("leaderboard", self.board)
  end

  def insert_record(name, value)
    var next = []
    var inserted = false
    for row : self.board
      if !inserted && value > row[1]
        next.push([name, value])
        inserted = true
      end
      if size(next) < 5 next.push(row) end
    end
    if !inserted && size(next) < 5 next.push([name, value]) end
    self.board = next
    self.best = size(next) > 0 ? next[0][1] : 0
  end

  def action(key, slot)
    if key == "quit" self.quit() return end
    if self.mode == "menu"
      if key == "left" self.menu_index = (self.menu_index + 3) % 4 end
      if key == "right" self.menu_index = (self.menu_index + 1) % 4 end
      if key == "a"
        if self.menu_index == 3 self.quit() return end
        if self.menu_index == 2
          self.mode = "scores"
          self.rank = 0
        else
          self.multiplayer = self.menu_index == 1
          store.set("last_multiplayer", self.multiplayer)
          if self.multiplayer
            self.mode = "controls"
            self.menu_index = self.separate ? 1 : 0
          else
            self.new_match(false)
          end
        end
      end
    elif self.mode == "controls"
      if key == "left" || key == "right" self.menu_index = 1 - self.menu_index end
      if key == "b" self.menu() return end
      if key == "a"
        self.separate = self.menu_index == 1
        store.set("separate_controls", self.separate)
        self.new_match(false)
      end
    elif self.mode == "scores"
      if key == "left" self.rank = max(0, self.rank - 1) end
      if key == "right" self.rank = min(max(0, size(self.board) - 1), self.rank + 1) end
      if key == "a" || key == "b" self.menu() return end
    elif self.mode == "ready"
      if key == "b" self.menu() return end
      if key == "a"
        if self.multiplayer && self.separate
          if slot == 0 || !gamepad.ready(slot) return end
          var expected = self.bindings[self.logical]
          if gamepad.ready(expected) && slot != expected return end
          self.bindings[self.logical] = slot
        end
        self.player = slot
        self.mode = "countdown"
        self.countdown_at = now_ms()
        self.gated = true
      end
    elif self.mode == "run"
      if key == "a" self.jump() end
      if key == "pause" self.pause() end
    elif self.mode == "pause"
      if key == "b" self.menu() return end
      if key == "a" || key == "pause"
        if self.recover
          # A fresh confirmation binds the active logical player to this slot.
          if slot > 0 && !gamepad.ready(slot) return end
          if self.multiplayer && self.separate && slot == 0 return end
          self.player = slot
          if self.multiplayer && self.separate self.bindings[self.logical] = slot end
          self.recover = false
        end
        if self.resume_countdown
          # The run never started: count down again rather than resuming
          # whatever state the previous run left behind.
          self.resume_countdown = false
          self.mode = "countdown"
          self.countdown_at = now_ms()
        else
          self.pause()
        end
      end
    elif self.mode == "initials"
      if self.multiplayer && self.separate && slot > 0 && slot != self.bindings[self.completed[self.pending]] return end
      if key == "left" self.initials[self.letter] = (self.initials[self.letter] + 25) % 26 end
      if key == "right" self.initials[self.letter] = (self.initials[self.letter] + 1) % 26 end
      if key == "b" self.letter = max(0, self.letter - 1) end
      if key == "a"
        if self.letter < 2
          self.letter += 1
        else
          self.add_record(self.initials_text(), self.scores[self.completed[self.pending]])
          self.pending += 1
          self.next_initials()
        end
      end
    elif self.mode == "results"
      if key == "left" || key == "right" self.menu_index = 1 - self.menu_index end
      if key == "b" self.menu() return end
      if key == "a"
        if self.menu_index == 0 self.new_match(true) else self.menu() end
      end
    end
    # Every menu action waits for release before another action can be accepted.
    if self.mode != "run" self.gated = true end
  end

  def on_button_event(btn, event)
    if btn == "left" && event == "long" && self.left_pending
      self.left_pending = false
      self.action("b", 0)
      return true
    end
    if event == "release"
      if btn == "right" self.local_duck = false end
      if btn == "select" self.local_jump = false end
      self.local_pressed = false
      if btn == "left" && self.left_pending
        self.left_pending = false
        self.action("left", 0)
      end
      return true
    end
    if event != "press" return true end
    self.local_pressed = true
    if self.gated return true end
    if self.mode == "run"
      if self.player != 0 return true end
      if btn == "right" self.local_duck = true end
      if btn == "select"
        self.local_jump = true
        self.action("a", 0)
      end
      if btn == "left" self.action("pause", 0) end
    else
      if btn == "left"
        if self.mode == "initials" self.left_pending = true else self.action("left", 0) end
      end
      if btn == "right" self.action("right", 0) end
      if btn == "select" self.action("a", 0) end
    end
    return true
  end

  def pause()
    if self.mode == "run"
      self.mode = "pause"
      self.jump_until = 0
    elif self.mode == "pause"
      self.mode = "run"
      self.gated = true
    end
    self.accumulator = 0
    self.last = now_ms()
  end

  def step()
    if !self.active return end
    var ms = now_ms()
    var elapsed = clamp(ms - self.last, 0, 100)
    self.last = ms
    var masks = [gamepad.buttons(1), gamepad.buttons(2)]
    var names = [gamepad.ready(1) ? gamepad.name(1) : "", gamepad.ready(2) ? gamepad.name(2) : ""]
    if (self.mode == "run" || self.mode == "countdown") && self.player > 0
      if !gamepad.ready(self.player) || names[0] != self.pad_names[0] || names[1] != self.pad_names[1]
        self.resume_countdown = self.mode == "countdown"
        self.mode = "pause"
        self.recover = true
        self.jump_until = 0
        self.gated = true
      end
    end
    self.pad_names = names
    gamepad.claim(self, 1)
    gamepad.claim(self, 2)
    # One direction read per controller per tick, shared by every check below.
    var dirs = [gamepad.dir(1), gamepad.dir(2)]
    var neutral = masks[0] == 0 && masks[1] == 0 && !self.local_pressed
    for dir : dirs
      if dir != nil && (dir[0] != 0 || dir[1] != 0) neutral = false end
    end
    if self.gated
      if neutral self.gated = false end
    else
      for slot : 1..2
        var buttons = masks[slot - 1]
        var newly = buttons & (~self.previous[slot - 1])
        var dir = dirs[slot - 1]
        var dx = dir == nil ? 0 : dir[0]
        var dy = dir == nil ? 0 : dir[1]
        var allowed = self.mode != "run" && self.mode != "countdown" && self.mode != "pause"
        allowed = allowed || slot == self.player || self.recover
        if allowed
          if (newly & self.bit_select) != 0 self.quit() return end
          if (newly & self.bit_start) != 0 self.action("pause", slot)
          elif (newly & self.bit_a) != 0 || (dy < 0 && self.up_previous[slot - 1] >= 0) self.action("a", slot)
          elif (newly & self.bit_b) != 0 self.action("b", slot)
          elif dx < 0 && self.dx_previous[slot - 1] >= 0 self.action("left", slot)
          elif dx > 0 && self.dx_previous[slot - 1] <= 0 self.action("right", slot)
          end
        end
        self.up_previous[slot - 1] = dy
        self.dx_previous[slot - 1] = dx
        if self.gated break end
      end
    end
    for slot : 1..2
      var d = dirs[slot - 1]
      self.up_previous[slot-1] = d == nil ? 0 : d[1]
      self.dx_previous[slot-1] = d == nil ? 0 : d[0]
    end
    self.previous = masks
    if self.mode == "countdown"
      if ms - self.countdown_at >= 3000
        self.seed = self.match_seed
        self.start(false)
        self.gated = true
      end
      return
    end
    if self.mode != "run" self.accumulator = 0 return end
    var buttons = self.player > 0 ? masks[self.player - 1] : 0
    var dir = self.player > 0 ? dirs[self.player - 1] : nil
    var up = dir != nil && dir[1] < 0
    var down = dir != nil && dir[1] > 0
    self.jump_held = !self.gated && (self.local_jump || (buttons & self.bit_a) != 0 || up)
    self.duck = !self.gated && self.y <= 0.0 && (self.local_duck || down || (buttons & self.bit_b) != 0)
    self.scene_ms += elapsed
    if self.ambient && self.density > 0 && self.fx_budget > 0 self.rain_step(elapsed) end
    self.accumulator += elapsed
    while self.accumulator >= 25 && self.mode == "run"
      self.accumulator -= 25
      self.physics()
    end
  end

  def physics()
    self.ticks += 1
    var speed = self.speed
    self.distance += speed * 0.025
    var points = int(self.distance)
    if points != self.score
      self.score = points
      self.label = str(self.score)
    end
    if !self.demo && !self.record_announced && self.score > self.record_target
      self.record_announced = true
      self.play_event("record")
    end
    var next_stage = self.score / self.switch_score
    while self.stage < next_stage
      self.stage += 1
      # Starting-speed limits do not cap speed earned during a run.
      self.speed *= 1.0 + self.difficulty / 100.0
      if store.get("debug", false) log(format("Dino stage %d: %.2f px/s", self.stage, self.speed)) end
      self.palette()
      self.play_event("switch")
    end
    if self.demo
      self.autoplay(speed)
    end
    self.travel += speed * 0.025
    if self.travel >= 52.0 self.travel -= 52.0 end
    if self.y <= 0.0 && self.jump_until > now_ms()
      self.launch()
      self.duck = false
      self.jump_until = 0
    end
    if self.y > 0.0 || self.vy > 0.0
      self.jump_age += 25
      if !self.demo && !self.jump_cut
        if !self.jump_held
          # Release before 400ms keeps the initial small jump.
          self.jump_cut = true
          self.play_event("small")
        elif self.jump_age >= 400
          # Promote to high jump only after the hold threshold. Starting small
          # prevents a late short press from already exceeding the screen top.
          self.vy = math.sqrt(max(0.0, 2.0 * self.jump_gravity * (17.0 - self.y)))
          self.jump_cut = true
          self.play_event("high")
        end
      end
    end
    # Velocity scales with game speed, gravity with its square: same height,
    # faster ascent/descent and less airtime at higher scrolling speeds.
    self.y += self.vy * 0.025 - 0.5 * self.jump_gravity * 0.025 * 0.025
    self.vy -= self.jump_gravity * 0.025
    if self.y <= 0.0
      self.y = 0.0
      self.vy = 0.0
    end
    # Re-evaluate duck after landing, without allocating a D-pad list.
    self.duck = self.duck && self.y <= 0.0
    for o : self.obstacles
      o[0] -= speed * 0.025
    end
    for o : self.obstacles
      if o[0] + o[2] < 0.0
        var far = -1000.0
        for other : self.obstacles
          if other != o far = max(far, other[0] + other[2]) end
        end
        o[0] = far + self.spacing(speed)
        self.choose_type(o)
      end
    end
    var dy = round(self.y)
    var ph = self.duck ? 3 : 6
    var pw = self.duck ? 7 : 5
    var py = 14 - dy - ph
    for o : self.obstacles
      var ox = round(o[0])
      var oy = o[1] == 1 ? 8 : 14 - o[3]
      # Exclusive right/bottom edges: a shared edge is not a collision.
      if 6 < ox + o[2] && 6 + pw > ox && py < oy + o[3] && py + ph > oy
        self.finish_run()
        return
      end
    end
  end

  def play_event(name)
    if !self.audio || self.demo return end
    try
      sound.effect(self.tunes[name])
    except .. as err, msg
      # Audio errors must never stop controller polling or game physics.
      self.audio = false
      log("Dino sound disabled: " + str(msg))
    end
  end

  def launch()
    var factor = self.speed / 20.0
    self.jump_gravity = 24.0 * factor * factor
    self.vy = math.sqrt(2.0 * self.jump_gravity * (self.demo ? 17.0 : 8.0))
    self.jump_age = 0
    self.jump_cut = self.demo
    self.duck = false
  end

  def reset_obstacles()
    # Six recycled obstacles instead of two; use spacing settings from spawn one.
    self.obstacles = []
    var x = 56.0
    for i : 0 .. 5
      var o = [x, 0, 5, 4]
      self.choose_type(o)
      self.obstacles.push(o)
      x += o[2] + self.spacing(self.speed)
    end
  end

  def spacing(speed)
    # Jump velocity scales with scroll speed, so short-jump travel stays constant.
    # 34px minimum gap leaves landing/reaction room. 0% is exactly 51px;
    # 100% ranges from 34 to 68px, both closer and farther than the midpoint.
    var spread = 17 * self.distance_randomness / 100
    if spread == 0 return 51 end
    return 51 + self.random(spread * 2 + 1) - spread
  end

  def choose_type(o)
    o[1] = 0
    o[2] = 5
    o[3] = 4
    if self.random(100) < self.type_randomness
      var pick = self.random(self.score >= 300 ? 4 : 3)
      if pick == 2
        o[1] = 2
        o[3] = 3
      elif pick == 3
        o[1] = 1
        o[3] = 3
      else
        o[3] = 4 + self.random(2)
      end
    end
  end

  def rain_random(n)
    # Independent RNG: visual effects never change obstacle generation.
    self.rain_seed = (self.rain_seed * 75 + 74) % 65521
    return self.rain_seed % n
  end

  def rain_step(elapsed)
    for drop : self.drops
      drop[0] += drop[1] * elapsed / 1000.0
      if drop[0] - drop[2] > height()
        drop[0] = -self.rain_random(10) * 1.0
        drop[1] = 4 + self.rain_random(9)
        drop[2] = 10 + self.rain_random(6)
      end
    end
  end

  def build_rain_ramps()
    # Precomputed tail colours for each drop length (10..15), indexed by length.
    # Direct brightness scaling: no minimum, no gamma lift, no forced lit tail.
    var peak = 144.0 * self.matrix_brightness / 100.0
    self.rain_ramps = []
    for length : 0 .. 15
      var ramp = nil
      if length >= 10
        ramp = []
        for tail : 0 .. length - 1
          # Last tail pixel is exactly black. Fractional levels are quantized only
          # at output; at very low brightness neighbouring levels may coincide.
          var ratio = (length - 1 - tail) / ((length - 1) * 1.0)
          var green = int(peak * ratio)
          ramp.push(green > 0 ? rgb(0, green, 0) : 0)
        end
      end
      self.rain_ramps.push(ramp)
    end
  end

  def rain_draw()
    if self.matrix_brightness <= 0 return end
    var stride = max(1, 101 / max(1, min(self.density, self.fx_budget)))
    var columns = width()
    # Rows 14-15 are always covered by the ground drawn afterwards.
    var bottom = 13
    var x = 0
    while x < columns
      var drop = self.drops[x]
      var head = int(drop[0])
      var ramp = self.rain_ramps[drop[2]]
      # Only the tail pixels that land on visible sky rows.
      for tail : max(0, head - bottom) .. min(size(ramp) - 1, head)
        var c = ramp[tail]
        if c != 0 pixel(x, head - tail, c) end
      end
      x += stride
    end
  end

  def mist()
    if !self.haze || self.haze_intensity <= 0 return end
    var t = self.scene_ms / 1000.0
    var r = (self.bg >> 16) & 255
    var g = (self.bg >> 8) & 255
    var b = self.bg & 255
    # Slow, broad mist wisps drift horizontally, with strongest haze near ground.
    # Low resolution blocks are intentional on a 52x16 matrix; no rainbow plasma.
    for x : 0 .. 25
      var band = 0.5 + 0.5 * math.sin(x * 0.23 - t * 0.35)
      var drift = math.sin(x * 0.13 - t * 0.21) * 1.4
      for row : 0 .. 3
        var y = 6 + row * 2
        var ribbon = max(0.0, 1.0 - math.abs(y - (10.0 + drift)) / 5.0)
        var alpha = band * ribbon * self.haze_intensity / 160.0
        var hr = int(r + (100 - r) * alpha)
        var hg = int(g + (112 - g) * alpha)
        var hb = int(b + (120 - b) * alpha)
        rect_fill(x * 2, y, 2, 2, rgb(hr, hg, hb))
      end
    end
  end

  def init_worlds()
    # bg, far, mid, near, ground, soil, hazard light, hazard shade, sky accent
    self.worlds = [
      [0x06121A,0x0B2530,0x123921,0x285532,0x78A84B,0x322416,0x88C86A,0x547B45,0xB5993A],
      [0x1C0D03,0x3C180A,0x512B0E,0x64431C,0xBE9644,0x4B3014,0x67C46D,0xAD8655,0xD6AA42],
      [0x020C09,0x082017,0x15382C,0x305D38,0x6E9266,0x202E27,0xB5BBA0,0x6A8665,0x438A58],
      [0x020310,0x0D1029,0x22203B,0x473049,0x25A7BC,0x101C35,0xF28ACC,0xC7A850,0x4A83A0],
      [0x030B1C,0x182C48,0x28495B,0x406C79,0xB9DDDF,0x183C55,0x8BE6ED,0x5FADCF,0x8AA9BE],
      [0x100303,0x24090A,0x3D1410,0x5B2113,0xC45327,0x3E1110,0xEEA34A,0xAC6658,0xC46E28],
      [0x01020A,0x151526,0x303043,0x48475A,0x9DA2B4,0x25293A,0xBDCAD7,0x7496AE,0x287F8B],
      [0x040611,0x10152A,0x192A34,0x344243,0x607C71,0x22252F,0xA4B8C4,0x6C927C,0x607894],
      [0x030313,0x12112C,0x242248,0x353167,0x38A5BC,0x141E39,0x63E4ED,0xCE7DDC,0x557AB4],
      [0x000000,0x001307,0x00250F,0x00401A,0x009933,0x001508,0x66FF88,0x22BB55,0x33AA55]
    ]
    self.hills = [0,0,1,1,2,3,3,4,4,3,2,2,1,0,0,1,2,3,3,2,1,1,0,0,1,0]
    self.world = 0
    self.next_world = 0
    self.old_colors = self.worlds[0]
    self.colors = self.worlds[0]
    self.transition_at = -1000
    self.parallax = store.get("parallax_enabled", true)
    self.parallax_intensity = clamp(num(store.get("parallax_intensity"),100),0,100)/100.0
    self.ambient = store.get("ambient_effects", true)
    self.density = int(clamp(num(store.get("ambient_density"),25),0,100))
    self.fixed_world = int(clamp(num(store.get("fixed_world"),1),1,10))-1
    self.world_auto = store.get("world_mode", "auto") == "auto"
    # Seeded once, bounded, and independent of obstacle RNG.
    self.drops = []
    for x : 0..width()-1
      self.drops.push([-self.rain_random(20)*1.0,4+self.rain_random(9),10+self.rain_random(6)])
    end
  end

  def blend(a,b,f)
    var r = int(((a>>16)&255)*(1.0-f)+((b>>16)&255)*f)
    var g = int(((a>>8)&255)*(1.0-f)+((b>>8)&255)*f)
    var blue = int((a&255)*(1.0-f)+(b&255)*f)
    return rgb(r,g,blue)
  end

  def palette()
    var desired = self.world_auto ? (self.stage / 2) % 10 : self.fixed_world
    var target = self.worlds[desired]
    var next = []
    # Permanent night/cavern worlds retain their identity at every milestone.
    var night = self.stage % 2 == 1 && (desired == 0 || desired == 1 || desired == 2 || desired == 4 || desired == 6)
    for c : target
      next.push(night ? self.blend(0x000008,c,0.60) : c)
    end
    if desired == 0 && self.stage % 2 == 0 next[0] = self.blend(next[0],self.day_color,0.35) end
    if self.distance == 0.0
      self.old_colors = next
      self.colors = next
      self.world = desired
      self.next_world = desired
      self.transition_at = -1000
    else
      self.old_colors = self.colors
      self.colors = next
      self.next_world = desired
      self.transition_at = self.scene_ms
    end
    self.shade_phase = -1.0
    self.apply_palette()
  end

  def apply_palette()
    var phase = clamp((self.scene_ms-self.transition_at)/500.0,0.0,1.0)
    if phase >= 0.5 self.world = self.next_world end
    self.matrix = self.world == 9
    # Blend the nine world colours only when the transition phase moves; outside a
    # transition this happens once instead of dozens of times per frame.
    if phase != self.shade_phase
      self.shade_phase = phase
      var shades = []
      for i : 0 .. 8 shades.push(self.blend(self.old_colors[i],self.colors[i],phase)) end
      self.shades = shades
    end
    self.bg = self.shades[0]
    self.ground = self.shades[4]
    self.tint = self.player_color(self.logical)
    self.fg = self.matrix ? 0x66EE88 : 0xCCDDCC
    self.gold = self.matrix ? 0x55DD77 : 0xFFCC55
  end

  def shade(index)
    # Valid for the current frame: draw() refreshes the cache via apply_palette().
    return self.shades[index]
  end

  def player_color(logical)
    return self.matrix ? 0x66FF88 : self.player_colors[logical]
  end

  def offset(rate)
    return self.parallax ? round(self.distance*rate*self.parallax_intensity) : 0
  end

  def scenery()
    var w = self.world
    var far = self.shade(1)
    var mid = self.shade(2)
    var near = self.shade(3)
    var accent = self.shade(8)
    var f = self.offset(0.04)
    var m = self.offset(0.10)
    var n = self.offset(0.24)
    # Skyline family, decided once per frame rather than once per column.
    var kind = (w == 0 || w == 1 || w == 4 || w == 6 || w == 7) ? 0 : (w == 2 ? 1 : ((w == 3 || w == 9) ? 2 : 3))
    # Per-column strips wrap at 104 pixels, including all edge columns.
    for x : 0..51
      var a = (x+f)%104
      var b = (x+m)%104
      var h = self.hills[(a/2)%26]
      var j = self.hills[b%26]
      if kind == 0
        line(x,12-h,x,13,far)
        line(x,13-j/2,x,13,mid)
      elif kind == 1
        line(x,6+h/2,x,9+h/2,far)
        if b%13 < 2 line(x,7,x,13,mid) end
      elif kind == 2
        var top = 7+(a/7)%4
        line(x,top,x,13,far)
        if b%17 < 8
          line(x,8+(b/17)%3,x,13,mid)
          if b%4 == 0 pixel(x,10,near) end
        end
      else
        line(x,6,x,6+h,far)
        if b%21 < 4 line(x,6,x,8+j/2,mid) end
        if a%29 < 2 line(x,10,x,13,far) end
      end
    end
    # Small motifs give each world a readable identity without filling the sky.
    for i : 0..3
      var x = (i*26-m%104+104)%104-13
      if w == 0
        line(x,9,x+3,9,mid)
        pixel(x+1,8,mid)
      elif w == 1
        line(x,10,x,13,mid)
        line(x-1,11,x+1,11,mid)
      elif w == 2
        rect_fill(x,10,3,4,mid)
        line(x-1,10,x+3,10,near)
        pixel(x+1,12,far)
      elif w == 3
        line(x,8,x,12,near)
        pixel(x+2,9,accent)
      elif w == 4
        line(x,10,x,13,mid)
        line(x-1,11,x+1,11,near)
        pixel(x,10,accent)
      elif w == 5
        line(x,7,x,9,near)
        pixel(x,8,accent)
      elif w == 6
        line(x,11,x+4,11,mid)
        rect_fill(x-1,12,7,2,mid)
        line(x+2,9,x+2,10,near)
      elif w == 7
        line(x,10,x,13,mid)
        line(x-1,11,x+1,12,mid)
      elif w == 8
        line(x,9,x,12,near)
        pixel(x-1,11,mid)
        pixel(x+1,11,mid)
      else
        rect_fill(x,10,5,3,mid)
        line(x,10,x+4,10,near)
      end
    end
    # Sky accents stay below the HUD and above the normal runner silhouette.
    var sky_x = (43-f%104+104)%104
    if w == 0 || w == 1
      if self.stage%2 == 0
        circle_fill(sky_x,7,1,accent)
      else
        pixel(sky_x,6,accent)
        pixel(sky_x-1,7,accent)
        pixel(sky_x,8,accent)
      end
      var cloud = (25-f%104+104)%104
      line(cloud,6,cloud+3,6,far)
    elif w == 6
      circle_fill(sky_x,7,1,accent)
    end
    # Near-ground tufts. Their row-15 counterparts are drawn by draw() after the
    # ground line, which would cover anything drawn on row 15 here.
    if w == 0 || w == 2 || w == 7
      for i : 0..3
        pixel((i*13-n%52+52)%52,13,near)
      end
    end
    if self.haze && !self.matrix self.mist() end
    if self.ambient self.world_fx() end
  end

  def world_fx()
    if self.density <= 0 || self.fx_budget <= 0 return end
    if self.matrix
      self.rain_draw()
      return
    end
    var t = self.scene_ms/100
    var count = 1+min(self.density,self.fx_budget)/34
    var color = self.shade(8)
    var near = self.shade(3)
    var w = self.world
    for i : 0..count-1
      var x = (17+i*19+t/9)%52
      var y = 6+(t/4+i*3)%7
      if w == 4
        pixel(x,y,color)
      elif w == 7
        pixel(x,y,color)
        pixel(x-1,y+1,near)
      elif w == 5
        pixel(x,13-(t/3+i*2)%7,color)
      elif w == 1
        if t%20 < 3 pixel(x,12,near) end
      elif w == 2
        if t%30 < 10 pixel((i*23+t/30)%52,7+(t/5)%2,near) end
      elif w == 3
        if t%40 < 8 pixel((i*17+31)%52,8,color) end
      elif w == 8
        if t%23 < 3 pixel(x,11,color) end
      elif w == 6 || (w == 0 && self.stage%2 == 1)
        if t%30 < 15 pixel((i*19+23)%52,6+i%2,color) end
      elif w == 0
        if t%40 < 4 pixel(x,13,near) end
      end
    end
    if w == 7 && t%120 < 2
      pixel(40,6,color)
      pixel(39,7,color)
      pixel(40,8,color)
    end
  end

  def draw_obstacles()
    var light = self.shade(6)
    var dark = self.shade(7)
    for o : self.obstacles
      var x = round(o[0])
      if x >= width() || x+o[2] < 0 continue end
      if o[1] == 1
        pixel(x,9,light)
        rect_fill(x+1,9,3,1,dark)
        pixel(x+1,8,light)
        var wing = (self.ticks/6)%2 == 0 ? 8 : 10
        line(x+2,wing,x+4,wing,light)
      elif o[1] == 2
        line(x+1,11,x+3,11,light)
        line(x,12,x+4,12,dark)
        line(x,13,x+4,13,self.blend(0,dark,0.75))
      elif self.world == 0 || self.world == 1
        var top = 14-o[3]
        line(x+2,top,x+2,13,light)
        line(x,top+1,x,top+2,dark)
        line(x,top+2,x+2,top+2,dark)
        line(x+4,top,x+4,top+1,light)
        line(x+2,top+1,x+4,top+1,light)
      else
        var top = 14-o[3]
        rect_fill(x,top,5,o[3],dark)
        line(x,top,x+4,top,light)
        line(x,top,x,13,light)
        if self.world == 3
          pixel(x+1,top+1,light)
          pixel(x+3,top+1,light)
        elif self.world == 4 || self.world == 8
          line(x+2,top,x+2,13,light)
        elif self.world == 2
          line(x+1,12,x+3,12,self.shade(3))
        elif self.world == 9
          line(x+4,top,x+4,13,light)
        end
      end
    end
  end

  def autoplay(speed)
    self.duck = false
    for o : self.obstacles
      var gap = o[0] - 11.0
      if o[1] != 1 && gap > -5 && gap < speed * 0.65 && self.y <= 0.0
        self.launch()
      elif o[1] == 1 && o[0] < 26 && o[0] + 5 > 5 && self.y <= 0.0
        self.duck = true
      end
    end
  end

  def tiny_number(value, sx, tint)
    var remaining = min(9999, max(0, value))
    var count = size(str(remaining))
    for i : 0 .. count - 1
      var rows = self.digits[remaining % 10]
      remaining = remaining / 10
      for yy : 0 .. 4
        for xx : 0 .. 2
          if (rows[yy] & (1 << (2 - xx))) != 0
            pixel(sx + (count - 1 - i) * 4 + xx, yy, tint)
          end
        end
      end
    end
  end

  def draw_menu()
    var color = self.player_color(self.logical)
    var title = "DINO"
    var detail = ""
    if self.mode == "menu"
      var items = ["SOLO", "2 PLAYERS", "HIGH SCORE", "QUIT"]
      title = items[self.menu_index]
      detail = "<  A:OK  >"
    elif self.mode == "controls"
      title = self.menu_index == 0 ? "SHARED" : "SEPARATE"
      detail = "<  A:OK  >"
    elif self.mode == "ready"
      title = "P" + str(self.logical + 1) + " READY"
      detail = "A: START"
    elif self.mode == "countdown"
      title = "P" + str(self.logical + 1)
      detail = str(max(1, 3 - (now_ms() - self.countdown_at) / 1000))
    elif self.mode == "pause"
      title = self.recover ? "PAD LOST" : "PAUSED"
      detail = "A:RESUME"
    elif self.mode == "initials"
      var entering = self.completed[self.pending]
      color = self.player_color(entering)
      title = "P" + str(entering + 1) + " TOP 5"
      detail = self.initials_text()
      line(self.letter * 4, 15, self.letter * 4 + 2, 15, color)
    elif self.mode == "scores"
      title = size(self.board) == 0 ? "TOP 5" : str(self.rank+1)+" "+self.board[self.rank][0]
      detail = size(self.board) == 0 ? "NO SCORES" : str(self.board[self.rank][1])
    elif self.mode == "results"
      if self.multiplayer
        title = self.scores[0] == self.scores[1] ? "DRAW" : (self.scores[0] > self.scores[1] ? "P1 WINS!" : "P2 WINS!")
        var page = (now_ms()/2000)%3
        if page == 1 title = "P1:"+str(self.scores[0]) end
        if page == 2 title = "P2:"+str(self.scores[1]) end
      else
        title = "S:" + str(self.scores[0])
      end
      detail = self.menu_index == 0 ? "A:REMATCH" : "A:MENU"
      if self.multiplayer && self.scores[0] != self.scores[1]
        var winner = self.scores[0] > self.scores[1] ? 0 : 1
        color = self.player_color(winner)
      end
      for i : 0..2
        pixel((now_ms()/180+i*17)%52,7,color)
      end
    end
    self.small_text(title, 0, 1, color)
    self.small_text(detail, 0, 9, 0xAABBAA)
  end

  def small_text(value, x, y, color)
    # Custom compact 3x5 font keeps labels within 52 columns.

    for i : 0..size(value)-1
      if x + i * 4 + 2 >= width() break end
      var c = value[i..i]
      var rows = self.font.find(c)
      if rows == nil
        var digit = int(c)
        if digit != nil && digit >= 0 && digit <= 9 rows = self.digits[digit] end
      end
      if rows != nil
        for yy : 0..4
          for xx : 0..2
            if (rows[yy] & (1 << (2-xx))) != 0 pixel(x+i*4+xx,y+yy,color) end
          end
        end
      end
    end
  end

  def hud()
    if self.multiplayer && self.turn == 1
      self.small_text("T" + str(min(9999, self.scores[self.order[0]])), 0, 0, self.gold)
      self.tiny_number(min(9999, self.score), width() - size(str(min(9999,self.score))) * 4, self.fg)
      if self.score > self.scores[self.order[0]] && self.score <= self.scores[self.order[0]] + 15
        line(23, 0, 23, 3, self.tint)
      end
      return
    end
    # H + best on the left, current score on the right. Four digits each.
    line(0, 0, 0, 4, self.gold)
    line(2, 0, 2, 4, self.gold)
    line(0, 2, 2, 2, self.gold)
    self.tiny_number(self.demo ? self.best : max(self.best, self.score), 4, self.gold)
    if self.demo
      text(27, 6, "DEMO", self.gold)
    else
      var shown = min(9999, self.score)
      self.tiny_number(shown, width() - size(str(shown)) * 4, self.fg)
    end
  end

  def draw()
    var draw_started = now_ms()
    self.apply_palette()
    clear()
    rect_fill(0, 0, width(), height(), self.bg)
    # A countdown interrupted by pad loss has no run scene to show yet.
    if self.mode != "run" && (self.mode != "pause" || self.resume_countdown)
      self.draw_menu()
      return
    end
    self.scenery()
    line(0,14,width()-1,14,self.ground)
    line(0,15,51,15,self.shade(5))
    var near_offset = self.offset(0.24)
    for i : 0..3
      var nx = (i*13-near_offset%52+52)%52
      pixel(nx,15,self.shade(3))
      if self.world == 4 || self.world == 8 pixel(nx+1,15,self.shade(8)) end
    end
    self.draw_obstacles()
    var yy = 14 - round(self.y)
    if self.duck
      rect_fill(6, yy - 3, 7, 2, self.tint)
      pixel(11, yy - 3, self.bg)
      pixel(7, yy - 1, self.tint)
      pixel(11, yy - 1, self.tint)
    else
      rect_fill(8, yy - 6, 3, 3, self.tint)
      pixel(10, yy - 5, self.bg)
      rect_fill(6, yy - 4, 3, 3, self.tint)
      pixel(5, yy - 4, self.tint)
      pixel(9, yy - 3, self.tint)
      var foot = self.y > 0.0 ? 0 : round(self.travel / 2) % 2
      pixel(6 + foot * 2, yy - 1, self.tint)
    end
    self.hud()
    if self.mode == "pause"
      rect_fill(0,0,52,6,self.bg)
      rect_fill(0,8,40,6,self.bg)
      self.draw_menu()
    end
    if self.mode == "run" self.adapt_effects(now_ms() - draw_started > 20) end
  end

  def adapt_effects(slow)
    # Only ambient work adapts; gameplay never reads fx_budget. A draw using most
    # of a 25ms frame adds strain and fast draws drain it, so isolated hiccups
    # (e.g. garbage collection) fade out while sustained slowness (over ~1 in 5
    # draws) sheds a step of effects. A long fast streak restores a step.
    if slow
      self.fx_calm = 0
      self.fx_strain += 4
      if self.fx_strain >= 12
        self.fx_strain = 0
        self.fx_budget = max(0, self.fx_budget - 10)
      end
    else
      self.fx_strain = max(0, self.fx_strain - 1)
      self.fx_calm += 1
      if self.fx_calm >= 200
        self.fx_calm = 0
        self.fx_budget = min(100, self.fx_budget + 10)
      end
    end
  end
end

return DinoRunner()
