#!/usr/bin/env python3
"""Synthesise the game's sounds and encode them as MP3s in sounds/.

roar.mp3 plays when the dino hatches; crack1-3.mp3 play on the countdown beats.


The roar is generated from scratch (no samples, no speech voices): a deep, rough
glottal pulse train with a growl from period doubling, a chest resonance, breath
noise, an irregular low rumble, vowel formant filters and soft clipping. Its shape
follows the word R-O-A-R: a soft rolled R swells into an O, peaks on an open A and
fades on a darker, gently rolled R.

The eggshell cracks are clusters of tiny brittle clicks (band-passed noise bursts of
a few milliseconds) over a short dull knock of the shell. Each beat cracks harder:
more clicks, spread wider and louder, and the last one splinters on.

Requires the `lame` encoder on PATH (for example `brew install lame`).
"""
import argparse
import math
import pathlib
import random
import shutil
import struct
import subprocess
import tempfile
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
RATE = 22050
DURATION = 1.55
SEED = 7

# Curves over the roar's duration, as (fraction, value) points.
# Timeline: R 0-0.16, O 0.16-0.30, A 0.30-0.52, final R 0.52-1.
AMPLITUDE = [(0, 0.0), (0.04, 0.18), (0.16, 0.45), (0.30, 0.8), (0.40, 1.0),
             (0.52, 0.95), (0.75, 0.45), (1.0, 0.0)]
PITCH_HZ = [(0, 42), (0.16, 49), (0.30, 61), (0.42, 67), (0.52, 61), (1.0, 36)]
FORMANT1_HZ = [(0, 320), (0.16, 370), (0.30, 590), (0.52, 600), (0.62, 330), (1.0, 300)]
FORMANT2_HZ = [(0, 700), (0.16, 660), (0.30, 970), (0.52, 970), (0.62, 780), (1.0, 700)]
# The third resonance drops in the tail, giving the closing R its colour.
FORMANT3_HZ = [(0, 2500), (0.52, 2500), (0.64, 1700), (1.0, 1650)]
TRILL_DEPTH = [(0, 0.85), (0.14, 0.7), (0.20, 0.0), (0.52, 0.0), (0.62, 0.3), (1.0, 0.35)]
BREATH = [(0, 0.45), (0.3, 0.3), (0.52, 0.25), (1.0, 0.18)]
DRIVE = [(0, 1.6), (0.4, 2.8), (0.6, 2.2), (1.0, 1.6)]
# Low rumble mixed in before the clipper, which turns it into audible overtones
# even on a small speaker.
RUMBLE = [(0, 0.5), (0.3, 0.7), (0.52, 0.9), (1.0, 0.8)]


class Biquad:
    """RBJ cookbook band-pass (constant peak gain), low-pass or high-pass filter."""

    def __init__(self, kind, freq, q):
        self.kind = kind
        self.q = q
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(freq)

    def set(self, freq):
        w = 2 * math.pi * freq / RATE
        alpha = math.sin(w) / (2 * self.q)
        cos_w = math.cos(w)
        if self.kind == 'bp':
            b0, b1, b2 = alpha, 0.0, -alpha
        elif self.kind == 'lp':
            b0, b1, b2 = (1 - cos_w) / 2, 1 - cos_w, (1 - cos_w) / 2
        else:
            b0, b1, b2 = (1 + cos_w) / 2, -(1 + cos_w), (1 + cos_w) / 2
        a0, a1, a2 = 1 + alpha, -2 * cos_w, 1 - alpha
        self.b = (b0 / a0, b1 / a0, b2 / a0)
        self.a = (a1 / a0, a2 / a0)

    def __call__(self, x):
        b0, b1, b2 = self.b
        a1, a2 = self.a
        y = b0 * x + b1 * self.x1 + b2 * self.x2 - a1 * self.y1 - a2 * self.y2
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def curve(points, p):
    """Piecewise-linear value of a curve at fraction p."""
    for (p0, v0), (p1, v1) in zip(points, points[1:]):
        if p <= p1:
            f = 0.0 if p1 == p0 else (p - p0) / (p1 - p0)
            return v0 + (v1 - v0) * f
    return points[-1][1]


def roar():
    rnd = random.Random(SEED)
    f1, f2, f3 = Biquad('bp', 700, 4.0), Biquad('bp', 1150, 5.0), Biquad('bp', 2500, 6.0)
    body = Biquad('bp', 220, 1.5)                 # chest resonance
    rumble_lp = Biquad('lp', 220, 0.7)
    highpass, lowpass = Biquad('hp', 110, 0.7), Biquad('lp', 4200, 0.7)
    phase, cycle, jitter = 0.0, 0, 0.0
    wobble, wobble_target = 0.5, 0.5
    samples = []
    for i in range(int(DURATION * RATE)):
        t = i / RATE
        p = t / DURATION
        phase += curve(PITCH_HZ, p) * (1 + jitter) / RATE
        if phase >= 1.0:
            phase -= 1.0
            cycle += 1
            jitter = rnd.uniform(-0.06, 0.06)
        # Period doubling: every other pulse is weaker, which sounds like a growl.
        strength = 1.0 if cycle % 2 == 0 else 0.3
        source = (1.0 - 2.0 * phase) * strength + curve(BREATH, p) * rnd.uniform(-1, 1)
        if i % 64 == 0:
            f1.set(curve(FORMANT1_HZ, p))
            f2.set(curve(FORMANT2_HZ, p))
            f3.set(curve(FORMANT3_HZ, p))
        r_colour = min(1.0, max(0.0, (p - 0.52) * 8))
        voiced = (1.2 * f1(source) + 0.8 * f2(source) + (0.35 + 0.35 * r_colour) * f3(source)
                  + 0.9 * body(source))
        # Rumble: low noise whose level wanders irregularly about a dozen times a second.
        if i % 900 == 0:
            wobble_target = rnd.uniform(0.25, 1.0)
        wobble += (wobble_target - wobble) * 0.004
        voiced += 1.6 * curve(RUMBLE, p) * wobble * rumble_lp(rnd.uniform(-1, 1))
        voiced = lowpass(highpass(math.tanh(curve(DRIVE, p) * voiced)))
        # Rolled R: a tongue flutter opening and closing the sound.
        rate = 25 if p < 0.3 else 22
        flutter = 1.0 - curve(TRILL_DEPTH, p) * (0.5 + 0.5 * math.cos(2 * math.pi * rate * t))
        samples.append(voiced * curve(AMPLITUDE, p) * flutter)
    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak * 0.92 for s in samples]


def crack(level, seed):
    """Eggshell crack for beat level 1-3."""
    rnd = random.Random(seed)
    clicks = [3, 5, 8][level - 1]
    spread = [0.06, 0.11, 0.18][level - 1]
    gain = [0.6, 0.8, 1.0][level - 1]
    duration = spread + 0.12 + (0.08 if level == 3 else 0.0)
    out = [0.0] * int(duration * RATE)
    # The dull knock of the shell gives the crack body on a small speaker.
    knock = Biquad('bp', 420, 3.0)
    for i in range(int(0.03 * RATE)):
        t = i / RATE
        out[i] += 1.4 * knock(rnd.uniform(-1, 1)) * math.exp(-t / 0.008)
    starts = sorted([0.0] + [rnd.uniform(0.004, spread) for _ in range(clicks - 1)])
    if level == 3:
        # Splinters keep trickling after the main break.
        starts += sorted(rnd.uniform(spread, spread + 0.08) for _ in range(4))
    for k, start in enumerate(starts):
        shell = Biquad('bp', rnd.uniform(2600, 5200), 2.5)
        ring = Biquad('bp', rnd.uniform(1500, 2200), 6.0)
        amp = rnd.uniform(0.55, 1.0) * (0.45 if k >= clicks else 1.0)
        decay = rnd.uniform(0.0015, 0.004)
        first = int(start * RATE)
        for i in range(int(0.02 * RATE)):
            if first + i >= len(out):
                break
            t = i / RATE
            noise = rnd.uniform(-1, 1) * math.exp(-t / decay)
            out[first + i] += amp * (2.2 * shell(noise) + 0.8 * ring(noise))
    peak = max(abs(s) for s in out) or 1.0
    return [math.tanh(1.3 * s / peak) / math.tanh(1.3) * 0.92 * gain for s in out]


def write_wav(path, samples):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767))
                               for s in samples))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out-dir', type=pathlib.Path, default=ROOT / 'sounds')
    parser.add_argument('--wav', action='store_true', help='Also keep uncompressed WAVs next to the MP3s')
    args = parser.parse_args()
    lame = shutil.which('lame')
    if not lame:
        raise SystemExit('lame not found; install it, for example with: brew install lame')
    sounds = {'roar': roar(), 'crack1': crack(1, 31), 'crack2': crack(2, 32), 'crack3': crack(3, 33)}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, samples in sounds.items():
            wav = pathlib.Path(tmp) / (name + '.wav')
            write_wav(wav, samples)
            if args.wav:
                shutil.copyfile(wav, args.out_dir / wav.name)
            out = args.out_dir / (name + '.mp3')
            subprocess.run([lame, '--quiet', '-m', 'm', '-b', '32', wav, str(out)], check=True)
            print(f'Wrote {out} ({out.stat().st_size} bytes, {len(samples) / RATE:.2f} s)')


if __name__ == '__main__':
    main()
