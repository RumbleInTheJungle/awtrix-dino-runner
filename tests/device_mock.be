# Device boundary mock. Physics, sessions, persistence and renderer stay real Berry.
import math
import string
var clock_ms = 0
var saved = {}
var messages = []
var pad_masks = [0,0]
var pad_dirs = [nil,nil]
var pad_names = ["",""]
var claims = [false,false]
var closed = false
var paused = false
var store = module("store")
store.get = def(key, fallback) return saved.find(key, fallback) end
store.set = def(key, value) saved[key] = value end
var sound = module("sound")
sound.can = /x -> false
sound.effect = /x -> nil
var timer = module("timer")
timer.every = def(ms, callback) return 1 end
var rotation = module("rotation")
rotation.pause = def() paused = true end
rotation.resume = def() paused = false end
rotation.close = def() closed = true end
rotation.next = / -> nil
var test_gamepad = module("gamepad")
test_gamepad.buttons = /p -> pad_masks[p-1]
test_gamepad.ready = /p -> pad_names[p-1] != ""
test_gamepad.name = /p -> pad_names[p-1]
test_gamepad.dir = /p -> pad_dirs[p-1]
test_gamepad.bit = def(key)
  return {"A":1,"B":2,"START":2048,"SELECT":1024}.find(key,0)
end
test_gamepad.claim = def(who,p) claims[p-1]=true end
test_gamepad.release = def(who,p) claims[p-1]=false end
def now_ms() return clock_ms end
def width() return 52 end
def height() return 16 end
def min(a,b) return a<b?a:b end
def max(a,b) return a>b?a:b end
def clamp(x,lo,hi) return min(hi,max(lo,x)) end
def num(x,fallback) if x==nil return fallback end return real(x) end
def round(x) return int(math.floor(x+0.5)) end
def rgb(r,g,b) return (int(r)<<16)|(int(g)<<8)|int(b) end
def log(s) messages.push(s) end
def text(x,y,s,c) return nil end
# Apply actual script-header defaults in the runner before constructing the game.
