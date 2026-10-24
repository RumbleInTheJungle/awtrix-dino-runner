# @name Dino Runner
# @ondemand
# @config p2_color color "P2 dino color" default=#FF3355 group="Players"
# @config debug bool "Debug logging" default=false group="Diagnostics"
# @config dino_color color "P1 / solo dino color" default=#3399FF group="Players"
# @config reset_best bool "Reset high scores (one shot)" default=false
# @config daylight color "Daylight color" default=#181E14
# @config haze bool "Moving haze" default=false
# @config haze_intensity slider "Haze intensity (0–100%)" default=25 min=0 max=100 unit=%
# @config matrix_brightness slider "Matrix rain brightness (0–100%)" default=40 min=0 max=100 unit=%
# @config sounds bool "Game sounds" default=true
# @config sound_volume slider "Game sound volume (0–100%)" default=60 min=0 max=100 unit=%
# Native AWTRIX NG TC002 game, 52x16. No server or MQTT required.
# Player 1: A jump/start/retry, B or D-pad down duck, START pause,
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
  var audio, tunes, record_target, record_announced

  var logical, multiplayer, separate, first, order, turn, match_seed, scores, completed
  var board, pending, initials, letter, menu_index, rank, gated, recover, countdown_at
  var previous, up_previous, dx_previous, pad_names, local_pressed, scene_ms

  def init()
    self.mode = "menu"
    self.multiplayer = store.get("last_multiplayer", false)
    self.separate = store.get("separate_controls", false)
    self.menu_index = self.multiplayer ? 1 : 0
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
    self.scene_ms = 0
    self.countdown_at = 0
    self.match_seed = 1
    self.order = [0, 1]
    self.initials = [0, 0, 0]
    self.letter = 0
    self.audio = store.get("sounds") && sound.can("song")
    self.record_target = 0
    self.record_announced = false
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
    self.matrix = store.get("matrix")
    self.matrix_brightness = int(clamp(num(store.get("matrix_brightness"), 40), 0, 100))
    self.rain_seed = now_ms() % 65521 + 17
    self.drops = []
    if self.matrix
      for x : 0 .. width() - 1
        self.drops.push([-self.rain_random(20) * 1.0, 4 + self.rain_random(9), 10 + self.rain_random(6)])
      end
    end
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
    self.tint = self.logical == 1 ? store.get("p2_color", 0xFF3355) : store.get("dino_color", 0x3399FF)
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
    if type(saved) == "list"
      for row : saved
        if type(row) == "list" && size(row) == 2 && type(row[0]) == "string" && size(row[0]) == 3 && type(row[1]) == "int" && row[1] > 0
          self.add_record(row[0], row[1])
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
    rotation.pause()
  end

  def save_best()
    # Records are saved only after a completed run and initials entry.
  end

  def on_hide()
    self.active = false
    self.local_duck = false
    self.local_jump = false
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
    self.scores = [0, 0]
    self.completed = []
    self.turn = 0
    self.prepare_turn()
  end

  def prepare_turn()
    self.logical = self.multiplayer ? self.order[self.turn] : 0
    self.player = self.separate ? self.logical + 1 : 1
    self.mode = "ready"
    self.gated = true
    self.recover = false
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
    store.set("leaderboard", next)
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
        if self.separate && (slot != self.logical + 1 || !gamepad.ready(slot)) return end
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
          if self.separate && slot == 0 return end
          self.player = slot
          self.recover = false
        end
        self.pause()
      end
    elif self.mode == "initials"
      if self.separate && slot != self.completed[self.pending] + 1 return end
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
    if event == "release"
      if btn == "right" self.local_duck = false end
      if btn == "select" self.local_jump = false end
      self.local_pressed = false
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
      if btn == "left" self.action("left", 0) end
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
        self.mode = "pause"
        self.recover = true
        self.jump_until = 0
        self.gated = true
      end
    end
    self.pad_names = names
    gamepad.claim(self, 1)
    gamepad.claim(self, 2)
    var neutral = masks[0] == 0 && masks[1] == 0 && !self.local_pressed
    for slot : 1..2
      var dir = gamepad.dir(slot)
      if dir != nil && (dir[0] != 0 || dir[1] != 0) neutral = false end
    end
    if self.gated
      if neutral self.gated = false end
    else
      for slot : 1..2
        var buttons = masks[slot - 1]
        var newly = buttons & (~self.previous[slot - 1])
        var dir = gamepad.dir(slot)
        var dx = dir == nil ? 0 : dir[0]
        var dy = dir == nil ? 0 : dir[1]
        var allowed = self.mode != "run" && self.mode != "countdown" && self.mode != "pause"
        allowed = allowed || slot == self.player || self.recover
        if allowed
          if (newly & gamepad.bit("SELECT")) != 0 self.quit() return end
          if (newly & gamepad.bit("START")) != 0 self.action("pause", slot)
          elif (newly & gamepad.bit("A")) != 0 || (dy < 0 && self.up_previous[slot - 1] >= 0) self.action("a", slot)
          elif (newly & gamepad.bit("B")) != 0 self.action("b", slot)
          elif dx < 0 && self.dx_previous[slot - 1] >= 0 self.action("left", slot)
          elif dx > 0 && self.dx_previous[slot - 1] <= 0 self.action("right", slot)
          end
        end
        self.up_previous[slot - 1] = dy
        self.dx_previous[slot - 1] = dx
        if self.gated break end
      end
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
    var dir = self.player > 0 ? gamepad.dir(self.player) : nil
    var up = dir != nil && dir[1] < 0
    var down = dir != nil && dir[1] > 0
    self.jump_held = !self.gated && (self.local_jump || (buttons & gamepad.bit("A")) != 0 || up)
    self.duck = !self.gated && self.y <= 0.0 && (self.local_duck || down || (buttons & gamepad.bit("B")) != 0)
    self.scene_ms += elapsed
    if self.matrix self.rain_step(elapsed) end
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
        if self.demo
          self.start(true)
        else
          self.finish_run()
        end
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

  def rain_draw()
    if self.matrix_brightness <= 0 return end
    # Direct brightness scaling: no minimum, no gamma lift, no forced lit tail.
    var peak = 144.0 * self.matrix_brightness / 100.0
    for x : 0 .. width() - 1
      var drop = self.drops[x]
      var head = int(drop[0])
      var length = drop[2]
      for tail : 0 .. length - 1
        var py = head - tail
        # Last tail pixel is exactly black. Fractional levels are quantized only
        # at output; at very low brightness neighbouring levels may coincide.
        var ratio = (length - 1 - tail) / ((length - 1) * 1.0)
        var green = int(peak * ratio)
        if py >= 0 && py < height() && green > 0
          pixel(x, py, rgb(0, green, 0))
        end
      end
    end
  end

  def atmosphere()
    if self.matrix return end
    self.mist()
    var t = self.scene_ms / 1000.0
    if self.stage % 2 == 1
      for star : self.stars
        var twinkle = int(45 + 140 * (0.5 + 0.5 * math.sin(t * 2.2 + star[2])))
        pixel(star[0], star[1], rgb(twinkle, twinkle, min(255, twinkle + 25)))
      end
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

  def palette()
    if self.matrix
      self.bg = 0x000000
      self.tint = 0x66FF88
      self.fg = 0x66EE88
      self.gold = 0x55DD77
      self.ground = 0x009933
      return
    end
    self.tint = self.logical == 1 ? store.get("p2_color", 0xFF3355) : store.get("dino_color", 0x3399FF)
    if self.stage % 2 == 0
      # Dim daylight avoids a glaring full-brightness white LED background.
      self.bg = self.day_color
      self.fg = 0xCCDDCC
      self.gold = 0xFFCC55
      self.ground = 0x668855
    else
      self.bg = 0x000008
      self.fg = 0x8899BB
      self.gold = 0xDDBBFF
      self.ground = 0x334466
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
    var color = self.matrix ? 0x66FF88 : (self.logical == 1 ? store.get("p2_color", 0xFF3355) : store.get("dino_color", 0x3399FF))
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
      title = "P" + str(self.completed[self.pending] + 1) + " TOP 5"
      detail = self.initials_text()
      line(self.letter * 4, 15, self.letter * 4 + 2, 15, color)
    elif self.mode == "scores"
      title = "TOP 5"
      detail = size(self.board) == 0 ? "NO SCORES" : str(self.rank + 1) + " " + self.board[self.rank][0] + " " + str(self.board[self.rank][1])
    elif self.mode == "results"
      if self.multiplayer
        title = self.scores[0] == self.scores[1] ? "DRAW" : (self.scores[0] > self.scores[1] ? "P1 WINS!" : "P2 WINS!")
        if (now_ms() / 2000) % 2 == 1 title = "1:" + str(self.scores[0]) + " 2:" + str(self.scores[1]) end
      else
        title = "S:" + str(self.scores[0])
      end
      detail = self.menu_index == 0 ? "A:REMATCH" : "A:MENU"
    end
    self.small_text(title, 0, 1, color)
    self.small_text(detail, 0, 9, 0xAABBAA)
  end

  def small_text(value, x, y, color)
    # Custom compact 3x5 font keeps labels within 52 columns.
    var font = {
      "A":[2,5,7,5,5],"B":[6,5,6,5,6],"C":[3,4,4,4,3],"D":[6,5,5,5,6],
      "E":[7,4,6,4,7],"F":[7,4,6,4,4],"G":[3,4,5,5,3],"H":[5,5,7,5,5],
      "I":[7,2,2,2,7],"J":[1,1,1,5,2],"K":[5,5,6,5,5],"L":[4,4,4,4,7],
      "M":[5,7,7,5,5],"N":[5,7,7,7,5],"O":[2,5,5,5,2],"P":[6,5,6,4,4],
      "Q":[2,5,5,3,1],"R":[6,5,6,5,5],"S":[3,4,2,1,6],"T":[7,2,2,2,2],
      "U":[5,5,5,5,7],"V":[5,5,5,5,2],"W":[5,5,7,7,5],"X":[5,5,2,5,5],
      "Y":[5,5,2,2,2],"Z":[7,1,2,4,7],":":[0,2,0,2,0],"!":[2,2,2,0,2],
      "<":[1,2,4,2,1],">":[4,2,1,2,4]," ":[0,0,0,0,0]}
    for i : 0..size(value)-1
      if x + i * 4 + 2 >= width() break end
      var c = value[i..i]
      var rows = font.find(c)
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
    clear()
    rect_fill(0, 0, width(), height(), self.bg)
    if self.matrix self.rain_draw() end
    if self.mode != "run"
      self.draw_menu()
      return
    end
    self.atmosphere()
    if !self.matrix && self.stage % 2 == 0
      circle_fill(43, 8, 1, 0xDD9955)
    elif !self.matrix
      # Five-pixel crescent; explicit silhouette stays clear over mist.
      pixel(43, 6, 0xCCCCFF)
      line(42, 7, 43, 7, 0xAAAAEE)
      line(41, 8, 42, 8, 0xAAAAEE)
      line(42, 9, 43, 9, 0xAAAAEE)
      pixel(43, 10, 0xCCCCFF)
    end
    line(0, 14, width() - 1, 14, self.ground)
    for i : 0 .. 3
      pixel((round(i * 13 - self.travel) + 52) % 52, 15, self.ground)
    end
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
    for o : self.obstacles
      var ox = round(o[0])
      if o[1] == 1
        # Beak faces the runner; wings flap around a darker body.
        pixel(ox, 9, (self.matrix ? 0x77FF99 : 0xFFBB44))
        rect_fill(ox + 1, 9, 3, 1, (self.matrix ? 0x00CC44 : 0xCC8866))
        pixel(ox + 1, 8, (self.matrix ? 0x55EE77 : 0xEEAA88))
        var wing = (self.ticks / 6) % 2 == 0 ? 8 : 10
        line(ox + 2, wing, ox + 4, wing, (self.matrix ? 0x55EE77 : 0xEEAA88))
      elif o[1] == 2
        # Rounded boulder with a light top and dark base.
        line(ox + 1, 11, ox + 3, 11, (self.matrix ? 0x55DD77 : 0xAAA08C))
        line(ox, 12, ox + 4, 12, (self.matrix ? 0x00BB44 : 0x887E6C))
        line(ox, 13, ox + 4, 13, (self.matrix ? 0x009933 : 0x665E50))
      else
        # Saguaro silhouette: tall trunk, lifted arms, shaded stem.
        var top = 14 - o[3]
        line(ox + 2, top, ox + 2, 13, (self.matrix ? 0x33EE66 : 0x44DD77))
        line(ox, top + 1, ox, top + 2, (self.matrix ? 0x00BB44 : 0x22AA55))
        line(ox, top + 2, ox + 2, top + 2, (self.matrix ? 0x00BB44 : 0x22AA55))
        line(ox + 4, top, ox + 4, top + 1, (self.matrix ? 0x66FF88 : 0x66EE88))
        line(ox + 2, top + 1, ox + 4, top + 1, (self.matrix ? 0x66FF88 : 0x66EE88))
      end
    end
    self.hud()
  end
end

return DinoRunner()
