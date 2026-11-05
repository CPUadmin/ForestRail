"""Synthesises every sound of the game (N8). No recordings, no downloads, no licences:
everything comes from numpy. Run:  python tools/audio_sources/make_audio.py

Writes mono 16-bit 44.1 kHz WAV files to ForestRail/assets/audio and prints a table
(length, peak, loop seam) so a bad file is easy to spot. Loops are built with whole
cycles or a cross-fade, so they repeat without a click. Nothing here has been
auditioned by a person; the owner's listening is part of the acceptance of N8.
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ForestRail/assets/audio"
rng = np.random.default_rng(20261031)
report = []


def tt(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def band(x, lo, hi):
    """Zero-phase band-pass through the FFT; lo <= 0 means low-pass, hi >= Nyquist high-pass."""
    n = len(x)
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(f)
    if lo > 0:
        mask *= np.clip((f - lo) / (lo * 0.35 + 1.0), 0, 1)
    if hi < SR / 2:
        mask *= np.clip((hi - f) / (hi * 0.35 + 1.0), 0, 1)
    return np.fft.irfft(spectrum * mask, n)


def smooth_noise(seconds, rate):
    """Slow random curve in -1..1 changing about `rate` times a second."""
    n = int(seconds * SR)
    points = max(4, int(seconds * rate) + 2)
    knots = rng.uniform(-1, 1, points)
    return np.interp(np.arange(n) / n * (points - 1), np.arange(points), knots)


def loopify(x, crossfade=1.0):
    """Blend the tail into the head so the loop has no seam."""
    xf = int(crossfade * SR)
    fade = np.linspace(0, np.pi / 2, xf)
    out = x[:-xf].copy()
    out[:xf] = x[-xf:] * np.cos(fade) + x[:xf] * np.sin(fade)
    return out


def norm(x, peak=0.85):
    return x / max(1e-9, np.max(np.abs(x))) * peak


def put(buf, sig, start, circular=False):
    i = int(start * SR)
    if circular:
        idx = (i + np.arange(len(sig))) % len(buf)
        np.add.at(buf, idx, sig)
    else:
        end = min(len(buf), i + len(sig))
        if i < len(buf):
            buf[i:end] += sig[: end - i]


def reverb(x, circular=False):
    out = x.copy()
    for delay, gain in [(0.071, 0.33), (0.131, 0.26), (0.197, 0.19), (0.283, 0.13), (0.37, 0.08)]:
        shift = int(delay * SR)
        if circular:
            out += np.roll(x, shift) * gain
        else:
            out[shift:] += x[:-shift] * gain
    return out


def write(name, x, loop=False, peak=0.85):
    x = norm(x, peak) if peak else x
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    seam = abs(float(x[0]) - float(x[-1])) if loop else float("nan")
    report.append((name, len(x) / SR, float(np.max(np.abs(x))), float(np.sqrt(np.mean(x ** 2))), seam))


def mtof(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------- instruments ------------------------------------------------------------------
def pluck(freq, seconds, amp=1.0, decay=1.0):
    t = tt(seconds)
    sig = np.zeros_like(t)
    for k in range(1, 9):
        sig += (1.0 / k) * np.sin(2 * np.pi * k * freq * (1 + 0.0004 * k * k) * t) * np.exp(-t * decay * (1.4 + 1.1 * k))
    attack = np.minimum(1.0, t / 0.004)
    return sig * attack * amp


def pad(freq, seconds, amp=1.0):
    t = tt(seconds)
    sig = np.zeros_like(t)
    for detune in (-0.0018, 0.0, 0.0021):
        for k in range(1, 9):
            sig += (1.0 / k) * np.sin(2 * np.pi * k * freq * (1 + detune) * t + k)
    env = np.minimum(1.0, t / 0.9) * np.minimum(1.0, (seconds - t) / 1.2)
    return sig * env * amp / 3.0


def bass(freq, seconds, amp=1.0):
    t = tt(seconds)
    sig = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * 2 * freq * t) + 0.12 * np.sin(2 * np.pi * 3 * freq * t)
    env = np.minimum(1.0, t / 0.25) * np.minimum(1.0, (seconds - t) / 0.7)
    return sig * env * amp


def bell(freq, seconds, amp=1.0, decay=3.0):
    t = tt(seconds)
    sig = np.zeros_like(t)
    for ratio, level in [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1)]:
        sig += level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * (0.6 + ratio * 0.25))
    return sig * np.minimum(1.0, t / 0.002) * amp


def brass(freq, seconds, amp=1.0):
    t = tt(seconds)
    sig = np.zeros_like(t)
    for k in range(1, 12):
        sig += (1.0 / k) * np.sin(2 * np.pi * k * freq * t + 0.3 * k)
    env = np.minimum(1.0, t / 0.12) * np.minimum(1.0, (seconds - t) / 0.35)
    return sig * env * amp


def thump(freq_start, freq_end, seconds, decay):
    t = tt(seconds)
    freq = freq_end + (freq_start - freq_end) * np.exp(-t * 30)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * np.exp(-t * decay)


def impact(seconds, ring_freq, level=1.0, ring_decay=28.0):
    t = tt(seconds)
    click = band(noise(seconds), 700, 3200) * np.exp(-t * 130)
    thunk = np.sin(2 * np.pi * 90 * t) * np.exp(-t * 45)
    ring = np.sin(2 * np.pi * ring_freq * t) * np.exp(-t * ring_decay) * 0.3
    return (click * 0.9 + thunk * 0.8 + ring) * level


# ---------- ambient -----------------------------------------------------------------------
def make_ambient():
    n = 16
    wind = band(noise(n), 70, 900)
    gust = 0.55 + 0.45 * smooth_noise(n, 0.18)
    whistle = band(noise(n), 900, 1500) * (0.25 + 0.25 * np.clip(smooth_noise(n, 0.3), 0, 1))
    write("amb_wind.wav", loopify(wind * gust + whistle, 1.5), loop=True, peak=0.6)
    t = tt(12)
    ins = np.zeros_like(t)
    for carrier, pulse in [(4300, 24.0), (4700, 29.0), (5200, 33.0), (5600, 21.0)]:
        gate = np.clip(np.sin(2 * np.pi * pulse * t + rng.uniform(0, 6)), 0, 1) ** 2
        ins += np.sin(2 * np.pi * (carrier + 40 * smooth_noise(12, 0.5)) * t) * gate * (0.4 + 0.6 * np.clip(smooth_noise(12, 0.4), 0, 1))
    write("amb_insects.wav", loopify(ins, 1.0), loop=True, peak=0.4)
    water = band(noise(12), 180, 2600) * (0.5 + 0.5 * np.clip(smooth_noise(12, 0.6), 0, 1))
    for _ in range(40):
        start = rng.uniform(0, 11)
        tt_ = tt(0.12)
        f0 = rng.uniform(380, 900)
        put(water, np.sin(2 * np.pi * (f0 + 900 * tt_) * tt_) * np.exp(-tt_ * 30) * rng.uniform(0.2, 0.6), start)
    write("amb_water.wav", loopify(water, 1.0), loop=True, peak=0.55)

    def chirp(f0, f1, seconds, amp=1.0):
        t = tt(seconds)
        freq = f0 + (f1 - f0) * t / seconds
        return np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.sin(np.pi * t / seconds) ** 0.6 * amp

    b1 = np.zeros(int(1.2 * SR))
    for i in range(3):
        put(b1, chirp(3300 - i * 250, 2700 - i * 250, 0.09), 0.05 + i * 0.16)
    write("bird_1.wav", reverb(b1), peak=0.6)
    t = tt(0.7)
    b2 = np.sin(2 * np.pi * (3900 + 600 * np.sin(2 * np.pi * 28 * t)) * t) * np.sin(np.pi * t / 0.7) ** 0.7
    write("bird_2.wav", reverb(np.concatenate([b2, np.zeros(int(0.4 * SR))])), peak=0.55)
    cuckoo = np.zeros(int(1.0 * SR))
    put(cuckoo, (np.sin(2 * np.pi * 720 * tt(0.22)) + 0.3 * np.sin(2 * np.pi * 1440 * tt(0.22))) * np.sin(np.pi * tt(0.22) / 0.22), 0.05)
    put(cuckoo, (np.sin(2 * np.pi * 570 * tt(0.28)) + 0.3 * np.sin(2 * np.pi * 1140 * tt(0.28))) * np.sin(np.pi * tt(0.28) / 0.28), 0.32)
    write("bird_3.wav", reverb(cuckoo), peak=0.55)
    b4 = np.zeros(int(1.1 * SR))
    for i in range(2):
        put(b4, chirp(2000, 3600, 0.22), 0.04 + i * 0.4)
    write("bird_4.wav", reverb(b4), peak=0.55)


# ---------- music -------------------------------------------------------------------------
def make_music():
    beat = 60.0 / 72.0
    bar = 4 * beat
    length = 8 * bar
    buf = np.zeros(int(length * SR))
    chords = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [60, 64, 67]), (43, [55, 59, 62])] * 2
    for index, (root, tones) in enumerate(chords):
        start = index * bar
        for midi in tones:
            put(buf, pad(mtof(midi), bar + 1.4, 0.16), start, circular=True)
        put(buf, bass(mtof(root), bar + 0.4, 0.34), start, circular=True)
        pattern = [tones[0], tones[1], tones[2], tones[0] + 12, tones[2], tones[1], tones[0], tones[1]]
        for step, midi in enumerate(pattern):
            put(buf, pluck(mtof(midi), 1.6, 0.30), start + step * beat / 2, circular=True)
    melody = [(0, 0, 76, 1.5), (0, 2, 72, 0.5), (0, 3, 74, 1), (1, 0, 77, 1.5), (1, 2, 72, 0.5), (1, 3, 69, 1), (2, 0, 72, 1), (2, 1, 76, 1), (2, 2, 79, 1.5),
              (3, 0, 74, 2), (3, 2, 71, 1), (3, 3, 67, 1), (4, 0, 76, 1.5), (4, 2, 81, 0.5), (4, 3, 79, 1), (5, 0, 77, 1), (5, 1, 76, 1), (5, 2, 72, 2),
              (6, 0, 79, 1.5), (6, 2, 76, 0.5), (6, 3, 72, 1), (7, 0, 74, 1), (7, 1, 71, 1), (7, 2, 69, 2)]
    for b, bt, midi, dur in melody:
        put(buf, pluck(mtof(midi), 2.6, 0.5, decay=0.45), b * bar + bt * beat, circular=True)
    buf = reverb(buf, circular=True)
    write("music_menu.wav", buf, loop=True, peak=0.8)
    sting = np.zeros(int(4.0 * SR))
    for i, midi in enumerate([57, 60, 64, 69, 72, 76]):
        put(sting, pluck(mtof(midi), 2.4, 0.5, decay=0.6), 0.05 + i * 0.16)
    for midi in [57, 64, 69]:
        put(sting, pad(mtof(midi), 3.6, 0.22), 0.0)
    write("sting_start.wav", reverb(sting), peak=0.8)
    fin = np.zeros(int(10.0 * SR))
    for start, chord in [(0.0, [60, 64, 67, 72]), (1.6, [55, 59, 62, 67]), (3.2, [57, 60, 64, 69]), (4.8, [53, 57, 60, 65]), (6.4, [60, 64, 67, 72, 76])]:
        for midi in chord:
            put(fin, brass(mtof(midi), 3.0 if start > 6 else 1.8, 0.2), start)
    for start in [0.0, 1.6, 3.2, 4.8, 6.4]:
        put(fin, thump(120, 55, 0.7, 5.0) * 0.8, start)
    for i, midi in enumerate([84, 88, 91, 96]):
        put(fin, bell(mtof(midi), 3.0, 0.3), 6.5 + i * 0.14)
    write("finale.wav", reverb(fin), peak=0.85)


# ---------- machines ------------------------------------------------------------------------
def make_steam():
    t = tt(0.32)
    chuff = 0.85 * thump(130, 42, 0.32, 20) + 0.6 * band(noise(0.32), 250, 2200) * np.exp(-t * 17)
    write("steam_chuff.wav", chuff, peak=0.8)
    hiss = band(noise(4), 3000, 11000) * (0.7 + 0.3 * smooth_noise(4, 1.0))
    write("steam_hiss.wav", loopify(hiss, 0.8), loop=True, peak=0.45)
    t = tt(2.6)
    blow = band(noise(2.6), 1200, 6500) * np.minimum(1.0, t / 0.05) * np.minimum(1.0, (2.6 - t) / 0.9)
    blow += 0.15 * np.sin(2 * np.pi * 2900 * t) * np.minimum(1.0, t / 0.05) * np.minimum(1.0, (2.6 - t) / 0.9)
    write("steam_blow.wav", blow, peak=0.7)
    fire = band(noise(6), 0, 160) * 0.5
    for _ in range(70):
        pop = band(noise(0.012), 800, 4200) * np.exp(-tt(0.012) * 260) * rng.uniform(0, 1) ** 2
        put(fire, pop * 2.0, rng.uniform(0, 5.9), circular=True)
    write("fire_crackle.wav", loopify(fire, 0.6), loop=True, peak=0.5)
    whistle = np.zeros(int(1.8 * SR))
    t = tt(1.8)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 6 * t)
    whistle += np.sin(2 * np.pi * 520 * vib * t) + 0.7 * np.sin(2 * np.pi * 660 * vib * t) + 0.25 * band(noise(1.8), 1500, 5000)
    whistle *= np.minimum(1.0, t / 0.08) * np.minimum(1.0, (1.8 - t) / 0.3)
    write("whistle.wav", whistle, peak=0.6)


def make_petrol():
    def firing(period, count, jitter=0.0):
        n = int(period * count * SR)
        buf = np.zeros(n)
        for k in range(count):
            t = tt(0.12)
            pulse = np.sin(2 * np.pi * 85 * t) * np.exp(-t * 38) + 0.55 * band(noise(0.12), 0, 900) * np.exp(-t * 60) + 0.18 * band(noise(0.12), 1500, 5000) * np.exp(-t * 150)
            put(buf, pulse * rng.uniform(0.85, 1.15), k * period + rng.uniform(-jitter, jitter), circular=True)
        return buf
    write("petrol_idle.wav", firing(1 / 6.7, 8, 0.004), loop=True, peak=0.7)
    t = tt(1.0)
    run = np.zeros_like(t)
    for k in range(1, 25):
        run += (k ** -1.05) * np.sin(2 * np.pi * 35 * k * t + rng.uniform(0, 6))
    run += 0.12 * band(noise(1.0), 200, 2500)
    run *= 0.8 + 0.2 * np.sin(2 * np.pi * 70 * t)
    write("petrol_run.wav", run, loop=True, peak=0.7)
    start = np.zeros(int(2.6 * SR))
    t = tt(1.4)
    crank = (band(noise(1.4), 100, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(6 + 6 * t / 1.4) / SR * 1.0))) + 0.3 * np.sin(2 * np.pi * (200 + 80 * t) * t)
    put(start, crank * 0.6, 0.0)
    for k, at in enumerate([1.3, 1.48, 1.58, 1.72, 1.82, 1.93, 2.04, 2.16, 2.3, 2.45]):
        tp = tt(0.12)
        put(start, (np.sin(2 * np.pi * 85 * tp) * np.exp(-tp * 38) + 0.5 * band(noise(0.12), 0, 900) * np.exp(-tp * 60)) * (0.6 + 0.04 * k), at)
    write("petrol_start.wav", start, peak=0.8)
    stall = np.zeros(int(1.5 * SR))
    at = 0.0
    gap = 0.15
    level = 1.0
    while at < 1.3:
        tp = tt(0.12)
        put(stall, (np.sin(2 * np.pi * 80 * tp) * np.exp(-tp * 35) + 0.5 * band(noise(0.12), 0, 900) * np.exp(-tp * 55)) * level, at)
        at += gap
        gap *= 1.25
        level *= 0.82
    write("petrol_stall.wav", stall, peak=0.75)
    t = tt(0.4)
    clunk = np.sin(2 * np.pi * 120 * t) * np.exp(-t * 28) + 0.7 * band(noise(0.4), 600, 3500) * np.exp(-t * 110) + 0.3 * np.sin(2 * np.pi * 880 * t) * np.exp(-t * 40)
    write("gear.wav", clunk, peak=0.8)
    # the horn of the petrol car: two stacked tones, a car-like buzz
    t = tt(0.9)
    horn = np.zeros_like(t)
    for f0 in (415.0, 523.0):
        for k, amp in ((1, 1.0), (2, 0.5), (3, 0.33), (4, 0.2), (5, 0.12)):
            horn += amp * np.sin(2 * np.pi * f0 * k * t)
    horn *= np.minimum(1.0, t / 0.03) * np.minimum(1.0, (0.9 - t) / 0.12)
    write("horn.wav", horn, peak=0.6)


def make_electric():
    t = tt(2.0)
    hum = sum(a * np.sin(2 * np.pi * 120 * k * t + k) for k, a in [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.25), (6, 0.15), (8, 0.1)]) + 0.2 * np.sin(2 * np.pi * 60 * t)
    hum *= 1 + 0.12 * np.sin(2 * np.pi * 3 * t)
    write("electric_hum.wav", hum, loop=True, peak=0.6)
    whine = np.sin(2 * np.pi * 1800 * t) + 0.45 * np.sin(2 * np.pi * 2700 * t + 1) + 0.2 * np.sin(2 * np.pi * 3600 * t)
    whine *= 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t)
    write("electric_whine.wav", whine, loop=True, peak=0.4)
    t = tt(0.22)
    relay = np.zeros_like(t)
    for at, level in [(0.0, 1.0), (0.085, 0.7)]:
        i = int(at * SR)
        c = band(noise(0.06), 900, 5000) * np.exp(-tt(0.06) * 120) * level + np.sin(2 * np.pi * 1400 * tt(0.06)) * np.exp(-tt(0.06) * 80) * 0.4
        relay[i:i + len(c)] += c
    write("contactor.wav", relay, peak=0.75)


def make_rail_ticks():
    """One hit of one axle on a rail joint (B1.4). No pitched ring (it sounded like a xylophone):
    a short noise click, a dull rattle of the steel, a low thump of the sleeper and the ballast."""
    for name, lo, hi, thump, damp in [("rail_tick_a.wav", 900, 4200, 78, 40.0), ("rail_tick_b.wav", 700, 3600, 92, 46.0), ("rail_tick_c.wav", 1100, 5200, 70, 36.0)]:
        t = tt(0.22)
        click = band(noise(0.22), lo, hi) * np.exp(-t * 95)
        snap = band(noise(0.22), 3200, 12000) * np.exp(-t * 260) * 0.45
        rattle = band(noise(0.22), 250, 1400) * np.exp(-t * 32) * 0.5
        low = np.sin(2 * np.pi * (thump + 30 * np.exp(-t * 60)) * t) * np.exp(-t * damp) * 0.9
        buf = np.zeros(int(0.3 * SR))
        put(buf, click * 0.8 + snap + rattle + low, 0.0)
        write(name, buf, peak=0.8)


def make_rails_and_ui():
    make_rail_ticks()
    for name, gap, ring in [("rail_clack_a.wav", 0.062, 1250), ("rail_clack_b.wav", 0.075, 1080), ("rail_clack.wav", 0.07, 1180)]:
        buf = np.zeros(int(0.5 * SR))
        put(buf, impact(0.3, ring), 0.0)
        put(buf, impact(0.3, ring * 1.07, 0.8), gap)
        write(name, buf, peak=0.8)
    t = tt(2.0)
    squeal = sum(a * np.sin(2 * np.pi * (f + 8 * np.sin(2 * np.pi * r * t)) * t) for f, a, r in [(2850, 1.0, 1.0), (3120, 0.7, 2.0), (4410, 0.4, 3.0)]) + 0.25 * band(noise(2.0), 3000, 7000)
    squeal *= 0.75 + 0.25 * np.sin(2 * np.pi * 4 * t)
    write("brake.wav", loopify(squeal, 0.4), loop=True, peak=0.5)
    buf = np.zeros(int(0.6 * SR))
    put(buf, impact(0.5, 700, 1.0, 12.0), 0.0)
    put(buf, impact(0.5, 640, 0.6, 14.0), 0.11)
    write("coupler_clank.wav", buf, peak=0.8)
    t = tt(0.12)
    click = band(noise(0.12), 1000, 3500) * np.exp(-t * 130) + np.sin(2 * np.pi * 820 * t) * np.exp(-t * 60) * 0.6
    write("ui_click.wav", click, peak=0.7)
    coins = np.zeros(int(1.4 * SR))
    for i, midi in enumerate([84, 88, 91]):
        put(coins, bell(mtof(midi), 1.2, 0.5, decay=4.0), i * 0.09)
    write("coins.wav", coins, peak=0.7)
    t = tt(0.4)
    cargo = np.sin(2 * np.pi * 95 * t) * np.exp(-t * 22) + 0.6 * band(noise(0.4), 0, 700) * np.exp(-t * 35) + 0.25 * band(noise(0.4), 1200, 5000) * np.exp(-t * 90)
    write("cargo.wav", cargo, peak=0.8)


def make_landing():
    # B5.5: the train comes down on the rail after a hop: a heavy thud, the springs bottom out, the body creaks
    # and the load rattles. Its own sound, not the clip of the cargo.
    seconds = 1.1
    t = tt(seconds)
    body = thump(95, 42, seconds, 9.0) * 1.0
    slap = band(noise(seconds), 80, 900) * np.exp(-t * 28) * 0.9
    crack = band(noise(seconds), 1400, 5200) * np.exp(-t * 110) * 0.45
    buf = body + slap + crack
    # the springs: two quick bounces that fade
    for gap, level in [(0.12, 0.45), (0.23, 0.22)]:
        put(buf, thump(70, 40, 0.5, 14.0) * level, gap)
    # a short metal creak of the frame
    creak = np.sin(2 * np.pi * (410 + 60 * np.exp(-t * 6)) * t) * np.exp(-t * 7) * 0.12
    # rattle of loose things
    rattle = band(noise(seconds), 2200, 6500) * np.exp(-t * 14) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * 0.18
    write("land_thud.wav", buf + creak + rattle, peak=0.85)


def make_pole():
    # B6.1: the iron-shod tip of the pole truck meets the ground: four different knocks (dense soil, clay, stones, roots)
    # and the sound of the tip pulled out. Own random generator, so the other sounds stay as they were.
    prng = np.random.default_rng(20261105)
    def nz(seconds):
        return prng.standard_normal(int(seconds * SR))
    # dense soil: a short dull thud and a dry crack
    s = 0.55
    t = tt(s)
    dense = thump(120, 55, s, 16.0) * 1.0 + band(nz(s), 200, 1800) * np.exp(-t * 60) * 0.55 + band(nz(s), 1800, 6000) * np.exp(-t * 150) * 0.22
    write("pole_plant_dense.wav", dense, peak=0.8)
    # clay: a wet squelch, the tip sinks and sticks
    s = 0.8
    t = tt(s)
    wobble = np.sin(2 * np.pi * (180 + 90 * np.exp(-t * 7)) * t)
    clay = thump(90, 40, s, 11.0) * 0.8 + band(nz(s), 90, 700) * np.exp(-t * 9) * (0.6 + 0.4 * wobble) * 0.8 + band(nz(s), 700, 2400) * np.exp(-t * 26) * 0.22
    write("pole_plant_clay.wav", clay, peak=0.8)
    # stones: a bright clink and a scrape, the tip skids
    s = 0.7
    t = tt(s)
    stones = band(nz(s), 2500, 9000) * np.exp(-t * 55) * 0.8 + np.sin(2 * np.pi * 1850 * t) * np.exp(-t * 40) * 0.35 + np.sin(2 * np.pi * 2760 * t) * np.exp(-t * 55) * 0.2
    scrape = band(nz(s), 1200, 5200) * np.clip(np.sin(np.pi * np.clip((t - 0.08) / 0.45, 0, 1)), 0, 1) * (0.55 + 0.45 * np.sin(2 * np.pi * 47 * t)) * 0.3
    write("pole_plant_stones.wav", stones + scrape + thump(150, 80, s, 30.0) * 0.3, peak=0.8)
    # roots: a woody crunch with a creak, the tip grips
    s = 0.7
    t = tt(s)
    crunch = band(nz(s), 300, 2600) * np.exp(-t * 34) * (0.6 + 0.4 * np.sin(2 * np.pi * 60 * t)) * 0.7
    creak = np.sin(2 * np.pi * (260 + 120 * np.exp(-t * 8)) * t) * np.exp(-t * 7) * 0.22
    write("pole_plant_roots.wav", thump(105, 60, s, 15.0) * 0.8 + crunch + creak, peak=0.8)
    # the tip pulled out of the ground: a short suck and a pop
    s = 0.45
    t = tt(s)
    pull = band(nz(s), 150, 1400) * np.exp(-t * 11) * np.sin(np.pi * np.clip(t / 0.3, 0, 1)) * 0.7
    pop = np.sin(2 * np.pi * (320 - 120 * t) * t) * np.exp(-t * 28) * (t > 0.17) * 0.6
    write("pole_lift.wav", pull + pop, peak=0.7)


def make_sail():
    # B6.4: a sail that luffs (a snap of the cloth and a flutter) and the creak of the rigging under load.
    srng = np.random.default_rng(20261105)
    def nz(seconds):
        return srng.standard_normal(int(seconds * SR))
    s = 0.7
    t = tt(s)
    snap = band(nz(s), 350, 3200) * np.exp(-t * 26) * 0.8
    crack = band(nz(s), 2200, 7000) * np.exp(-t * 90) * 0.35
    flutter = band(nz(s), 250, 2600) * np.exp(-t * 9) * (0.5 + 0.5 * np.sin(2 * np.pi * 21 * t)) * 0.45
    body = thump(110, 60, s, 18.0) * 0.4
    write("sail_flap.wav", snap + crack + flutter + body, peak=0.8)
    s = 0.9
    t = tt(s)
    creak = np.sin(2 * np.pi * (180 + 70 * np.sin(2 * np.pi * 1.7 * t)) * t) * 0.5
    creak += np.sin(2 * np.pi * (365 + 120 * np.sin(2 * np.pi * 2.3 * t + 1.0)) * t) * 0.25
    scrape = band(nz(s), 900, 3600) * (0.5 + 0.5 * np.sin(2 * np.pi * 36 * t)) * 0.18
    env = np.sin(np.pi * np.clip(t / s, 0, 1)) ** 1.5
    write("sail_creak.wav", (creak + scrape) * env, peak=0.55)


def make_zeppelin():
    # B6.5: the rail zeppelin: a buzzing two-stroke engine (the pitch follows the revs), the whoosh of the blades, the wind of the speed,
    # the clank of the flaps and the crash. Written by the same rule: whole cycles in the loops, so that they repeat without a click.
    zrng = np.random.default_rng(20261106)
    def nz(seconds):
        return zrng.standard_normal(int(seconds * SR))
    t = tt(2.0)
    # the engine at about 1800 rpm: a ragged two-stroke buzz, 60 bangs a second with a little unevenness
    engine = np.zeros_like(t)
    for k in range(1, 30):
        engine += (k ** -0.9) * np.sin(2 * np.pi * 60 * k * t + zrng.uniform(0, 6))
    engine += 0.25 * band(nz(2.0), 300, 3000)
    engine *= 0.75 + 0.25 * np.sin(2 * np.pi * 30 * t) + 0.08 * np.sin(2 * np.pi * 4 * t)
    write("zep_engine.wav", engine, loop=True, peak=0.7)
    # the blades: a soft pulsing whoosh, 40 passes a second
    prop = band(nz(2.0), 160, 1800) * (0.55 + 0.45 * np.sin(2 * np.pi * 40 * t)) + 0.4 * band(nz(2.0), 1800, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * t + 1.2))
    write("zep_prop.wav", prop, loop=True, peak=0.6)
    # the wind of the speed
    wind = band(nz(3.0), 220, 5200) * (0.8 + 0.2 * smooth_noise(3.0, 3.0))
    write("zep_wind.wav", loopify(wind, 0.4), loop=True, peak=0.6)
    s = 0.6
    ts = tt(s)
    flaps = band(nz(s), 200, 2400) * np.sin(np.pi * np.clip(ts / s, 0, 1)) * 0.5
    flaps += np.sin(2 * np.pi * 140 * ts) * np.exp(-ts * 22) * 0.6 + band(nz(s), 1200, 6000) * np.exp(-ts * 70) * 0.5 * (ts > 0.25)
    write("zep_flaps.wav", flaps, peak=0.75)
    s = 1.6
    ts = tt(s)
    crash = band(nz(s), 80, 2200) * np.exp(-ts * 4.5) * 0.9 + thump(90, 38, s, 7.0) * 0.8
    for at in (0.12, 0.31, 0.55, 0.8):
        tp = tt(0.25)
        put(crash, (band(nz(0.25), 600, 5000) * np.exp(-tp * 26) + np.sin(2 * np.pi * zrng.uniform(300, 900) * tp) * np.exp(-tp * 20) * 0.4) * 0.6, at)
    write("zep_crash.wav", crash, peak=0.85)


def make_rain():
    rain_rng = np.random.default_rng(20261105)
    rain = 0.18 * band(rain_rng.normal(size=8 * SR), 650, 6500)
    drop_time = tt(0.026)
    for start in rain_rng.uniform(0, 7.95, 180):
        frequency = rain_rng.uniform(650, 2400)
        drop = np.sin(2 * np.pi * frequency * drop_time) * np.exp(-drop_time * 210)
        put(rain, drop * rain_rng.uniform(0.08, 0.28), start)
    write("amb_rain.wav", loopify(rain, 0.45), loop=True, peak=0.65)


if __name__ == "__main__":
    import sys
    OUT.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "landing":
        make_landing()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "rain":
        make_rain()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "pole":
        make_pole()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "sail":
        make_sail()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "zeppelin":
        make_zeppelin()
        sys.exit(0)
    make_ambient()
    make_music()
    make_steam()
    make_petrol()
    make_electric()
    make_rails_and_ui()
    make_landing()
    make_rain()
    make_pole()
    make_sail()
    make_zeppelin()
    print("%-22s %7s %6s %6s %8s" % ("file", "sec", "peak", "rms", "seam"))
    for name, seconds, peak, rms, seam in report:
        print("%-22s %7.2f %6.2f %6.3f %8.4f" % (name, seconds, peak, rms, seam))
